"""
Alert system for Smart Pollution Monitoring & Alert System.
Handles alert detection, creation, and Firebase push notifications.
"""

import logging
import os
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from threading import Thread

from models import PollutionData, Alert, DeviceToken, db

logger = logging.getLogger(__name__)

# Firebase Admin SDK - conditional import
firebase_admin = None
messaging = None

def init_firebase(credentials_path: Optional[str] = None):
    """
    Initialize Firebase Admin SDK for push notifications.
    
    Args:
        credentials_path: Path to Firebase service account credentials JSON file.
    """
    global firebase_admin, messaging
    
    try:
        import firebase_admin as fb_admin
        from firebase_admin import credentials, messaging as fb_messaging
        
        firebase_admin = fb_admin
        messaging = fb_messaging
        
        # Check if already initialized
        try:
            fb_admin.get_app()
            logger.info("Firebase already initialized")
            return True
        except ValueError:
            pass
        
        # Initialize with credentials
        if credentials_path and os.path.exists(credentials_path):
            cred = credentials.Certificate(credentials_path)
            fb_admin.initialize_app(cred)
            logger.info(f"Firebase initialized with credentials from {credentials_path}")
            return True
        elif os.environ.get('FIREBASE_CREDENTIALS'):
            import json
            cred_dict = json.loads(os.environ.get('FIREBASE_CREDENTIALS'))
            cred = credentials.Certificate(cred_dict)
            fb_admin.initialize_app(cred)
            logger.info("Firebase initialized with credentials from environment variable")
            return True
        else:
            logger.warning("Firebase credentials not found. Push notifications will be disabled.")
            return False
            
    except ImportError:
        logger.warning("Firebase Admin SDK not installed. Push notifications will be disabled.")
        return False
    except Exception as e:
        logger.error(f"Error initializing Firebase: {e}")
        return False


class AlertManager:
    """Manager for handling pollution and noise alerts."""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        """
        Initialize the alert manager.
        
        Args:
            config: Configuration dictionary with alert thresholds.
        """
        self.config = config or {}
        self.aqi_threshold = self.config.get('AQI_ALERT_THRESHOLD', 150)
        self.aqi_duration_minutes = self.config.get('AQI_ALERT_DURATION_MINUTES', 15)
        self.noise_threshold = self.config.get('NOISE_ALERT_THRESHOLD', 80)
        self.quiet_hours_start = self.config.get('NOISE_QUIET_HOURS_START', 22)
        self.quiet_hours_end = self.config.get('NOISE_QUIET_HOURS_END', 6)
    
    def check_aqi_alert(self) -> Optional[Alert]:
        """
        Check if AQI has been above threshold for the required duration.
        
        Returns:
            Alert object if alert triggered, None otherwise.
        """
        try:
            cutoff_time = datetime.utcnow() - timedelta(minutes=self.aqi_duration_minutes)
            
            # Get all records in the alert window
            recent_records = PollutionData.query.filter(
                PollutionData.timestamp >= cutoff_time
            ).order_by(PollutionData.timestamp.desc()).all()
            
            if not recent_records:
                logger.debug("No recent records for AQI alert check")
                return None
            
            # Check if all records are above threshold
            all_above_threshold = all(
                record.aqi > self.aqi_threshold for record in recent_records
            )
            
            if not all_above_threshold:
                return None
            
            # Check if there's already an active AQI alert
            existing_alert = Alert.query.filter_by(
                alert_type='high_aqi',
                status='Active'
            ).first()
            
            if existing_alert:
                logger.debug("Active AQI alert already exists")
                return None
            
            # Create new alert
            avg_aqi = sum(r.aqi for r in recent_records) / len(recent_records)
            alert = Alert(
                alert_type='high_aqi',
                message=f'AQI has exceeded {self.aqi_threshold} continuously for {self.aqi_duration_minutes} minutes. Current average: {avg_aqi:.0f}',
                status='Active'
            )
            
            db.session.add(alert)
            db.session.commit()
            
            logger.warning(f"High AQI alert triggered: {alert.message}")
            
            # Send push notification in background
            self._send_notification_async(
                title="⚠ High Pollution Alert",
                body=f"AQI has exceeded safe limits in Pune. Current: {avg_aqi:.0f}"
            )
            
            return alert
            
        except Exception as e:
            logger.error(f"Error checking AQI alert: {e}")
            return None
    
    def check_noise_alert(self) -> Optional[Alert]:
        """
        Check if noise level is above threshold during quiet hours.
        
        Returns:
            Alert object if alert triggered, None otherwise.
        """
        try:
            current_hour = datetime.utcnow().hour
            
            # Check if we're in quiet hours (10 PM - 6 AM)
            is_quiet_hours = (
                current_hour >= self.quiet_hours_start or 
                current_hour < self.quiet_hours_end
            )
            
            if not is_quiet_hours:
                return None
            
            # Get latest record with noise data
            latest = PollutionData.get_latest()
            
            if not latest or latest.noise is None:
                return None
            
            if latest.noise <= self.noise_threshold:
                return None
            
            # Check if there's already an active noise alert
            existing_alert = Alert.query.filter_by(
                alert_type='high_noise',
                status='Active'
            ).first()
            
            if existing_alert:
                logger.debug("Active noise alert already exists")
                return None
            
            # Create new alert
            alert = Alert(
                alert_type='high_noise',
                message=f'Noise level ({latest.noise:.1f} dB) has exceeded {self.noise_threshold} dB during quiet hours (10 PM - 6 AM)',
                status='Active'
            )
            
            db.session.add(alert)
            db.session.commit()
            
            logger.warning(f"High noise alert triggered: {alert.message}")
            
            # Send push notification in background
            self._send_notification_async(
                title="🔊 High Noise Alert",
                body=f"Noise level ({latest.noise:.1f} dB) exceeds safe limits during quiet hours."
            )
            
            return alert
            
        except Exception as e:
            logger.error(f"Error checking noise alert: {e}")
            return None
    
    def check_all_alerts(self) -> List[Alert]:
        """
        Run all alert checks.
        
        Returns:
            List of triggered alerts.
        """
        triggered_alerts = []
        
        aqi_alert = self.check_aqi_alert()
        if aqi_alert:
            triggered_alerts.append(aqi_alert)
        
        noise_alert = self.check_noise_alert()
        if noise_alert:
            triggered_alerts.append(noise_alert)
        
        # Auto-resolve alerts if conditions are back to normal
        self._auto_resolve_alerts()
        
        return triggered_alerts
    
    def _auto_resolve_alerts(self):
        """Automatically resolve alerts when conditions return to normal."""
        try:
            latest = PollutionData.get_latest()
            if not latest:
                return
            
            # Resolve AQI alert if AQI is now below threshold
            if latest.aqi <= self.aqi_threshold:
                active_aqi_alerts = Alert.query.filter_by(
                    alert_type='high_aqi',
                    status='Active'
                ).all()
                
                for alert in active_aqi_alerts:
                    alert.resolve()
                    logger.info(f"Auto-resolved AQI alert (ID: {alert.id})")
            
            # Resolve noise alert if noise is now below threshold or outside quiet hours
            current_hour = datetime.utcnow().hour
            is_quiet_hours = (
                current_hour >= self.quiet_hours_start or 
                current_hour < self.quiet_hours_end
            )
            
            should_resolve_noise = (
                (latest.noise is not None and latest.noise <= self.noise_threshold) or
                not is_quiet_hours
            )
            
            if should_resolve_noise:
                active_noise_alerts = Alert.query.filter_by(
                    alert_type='high_noise',
                    status='Active'
                ).all()
                
                for alert in active_noise_alerts:
                    alert.resolve()
                    logger.info(f"Auto-resolved noise alert (ID: {alert.id})")
                    
        except Exception as e:
            logger.error(f"Error auto-resolving alerts: {e}")
    
    def _send_notification_async(self, title: str, body: str):
        """
        Send push notification in a background thread.
        
        Args:
            title: Notification title.
            body: Notification body.
        """
        thread = Thread(target=self._send_push_notification, args=(title, body))
        thread.daemon = True
        thread.start()
    
    def _send_push_notification(self, title: str, body: str):
        """
        Send push notification to all registered devices.
        
        Args:
            title: Notification title.
            body: Notification body.
        """
        if not messaging:
            logger.warning("Firebase not initialized. Cannot send push notification.")
            return
        
        try:
            # Get all active device tokens
            tokens = DeviceToken.get_active_tokens()
            
            if not tokens:
                logger.info("No device tokens registered for push notifications")
                return
            
            # Prepare the message
            token_strings = [t.token for t in tokens]
            
            # Send to each token
            success_count = 0
            failure_count = 0
            
            for token_str in token_strings:
                try:
                    message = messaging.Message(
                        notification=messaging.Notification(
                            title=title,
                            body=body,
                        ),
                        data={
                            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                            'timestamp': datetime.utcnow().isoformat()
                        },
                        token=token_str,
                    )
                    
                    response = messaging.send(message)
                    logger.info(f"Push notification sent successfully: {response}")
                    success_count += 1
                    
                except Exception as e:
                    logger.error(f"Failed to send notification to token: {e}")
                    failure_count += 1
                    
                    # Deactivate invalid tokens
                    if 'NotRegistered' in str(e) or 'InvalidRegistration' in str(e):
                        DeviceToken.deactivate_token(token_str)
            
            logger.info(f"Push notifications sent: {success_count} success, {failure_count} failed")
            
        except Exception as e:
            logger.error(f"Error sending push notifications: {e}")
    
    def create_manual_alert(self, alert_type: str, message: str) -> Alert:
        """
        Create a manual alert.
        
        Args:
            alert_type: Type of alert.
            message: Alert message.
            
        Returns:
            Created Alert object.
        """
        alert = Alert(
            alert_type=alert_type,
            message=message,
            status='Active'
        )
        
        db.session.add(alert)
        db.session.commit()
        
        logger.info(f"Manual alert created: {alert_type} - {message}")
        return alert
    
    def resolve_alert(self, alert_id: int) -> bool:
        """
        Manually resolve an alert by ID.
        
        Args:
            alert_id: ID of the alert to resolve.
            
        Returns:
            True if resolved, False otherwise.
        """
        try:
            alert = Alert.query.get(alert_id)
            if alert:
                alert.resolve()
                logger.info(f"Alert {alert_id} resolved manually")
                return True
            return False
        except Exception as e:
            logger.error(f"Error resolving alert {alert_id}: {e}")
            return False


# Singleton instance (will be initialized with config in app.py)
alert_manager = None


def get_alert_manager(config: Optional[Dict[str, Any]] = None) -> AlertManager:
    """Get or create the alert manager instance."""
    global alert_manager
    if alert_manager is None:
        alert_manager = AlertManager(config)
    return alert_manager
