"""
Scheduler module for Smart Pollution Monitoring & Alert System.
Handles background jobs for fetching AQI data and running alert checks.
"""

import logging
from datetime import datetime
from typing import Optional, Dict, Any

import requests
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from apscheduler.events import EVENT_JOB_ERROR, EVENT_JOB_EXECUTED

from models import PollutionData, db
from alerts import get_alert_manager

logger = logging.getLogger(__name__)

# Global scheduler instance
scheduler = None


class AQIDataFetcher:
    """Fetcher for AQI data from external APIs."""
    
    def __init__(self, api_key: str, city: str, base_url: str):
        """
        Initialize the AQI data fetcher.
        
        Args:
            api_key: AQICN API key.
            city: City name for AQI data.
            base_url: Base URL for AQICN API.
        """
        self.api_key = api_key
        self.city = city
        self.base_url = base_url
    
    def fetch_current_aqi(self) -> Optional[Dict[str, Any]]:
        """
        Fetch current AQI data from AQICN API.
        
        Returns:
            Dictionary with AQI data or None if request failed.
        """
        try:
            url = f"{self.base_url}/feed/{self.city}/?token={self.api_key}"
            
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            
            if data.get('status') != 'ok':
                logger.error(f"AQICN API error: {data.get('message', 'Unknown error')}")
                return None
            
            api_data = data.get('data', {})
            
            # Extract pollutant data
            iaqi = api_data.get('iaqi', {})
            
            result = {
                'aqi': api_data.get('aqi'),
                'pm25': iaqi.get('pm25', {}).get('v'),
                'pm10': iaqi.get('pm10', {}).get('v'),
                'timestamp': datetime.utcnow(),
                'source': 'api',
                'city': self.city,
                'station': api_data.get('city', {}).get('name', 'Unknown')
            }
            
            logger.info(f"Fetched AQI data: AQI={result['aqi']}, PM2.5={result['pm25']}, PM10={result['pm10']}")
            return result
            
        except requests.exceptions.Timeout:
            logger.error("AQICN API request timed out")
            return None
        except requests.exceptions.RequestException as e:
            logger.error(f"AQICN API request failed: {e}")
            return None
        except Exception as e:
            logger.error(f"Error fetching AQI data: {e}")
            return None


class PollutionScheduler:
    """Scheduler for background pollution monitoring tasks."""
    
    def __init__(self, app, config: Dict[str, Any]):
        """
        Initialize the pollution scheduler.
        
        Args:
            app: Flask application instance.
            config: Configuration dictionary.
        """
        self.app = app
        self.config = config
        self.scheduler = BackgroundScheduler(
            timezone=config.get('SCHEDULER_TIMEZONE', 'UTC')
        )
        self.data_fetcher = AQIDataFetcher(
            api_key=config.get('AQICN_API_KEY', 'demo'),
            city=config.get('AQICN_CITY', 'pune'),
            base_url=config.get('AQICN_BASE_URL', 'https://api.waqi.info')
        )
        
        # Set up event listeners
        self.scheduler.add_listener(self._job_listener, EVENT_JOB_EXECUTED | EVENT_JOB_ERROR)
    
    def _job_listener(self, event):
        """Handle scheduler job events."""
        if event.exception:
            logger.error(f"Job {event.job_id} failed: {event.exception}")
        else:
            logger.debug(f"Job {event.job_id} executed successfully")
    
    def fetch_and_store_aqi(self):
        """Fetch AQI data from API and store in database."""
        with self.app.app_context():
            try:
                # Fetch data
                aqi_data = self.data_fetcher.fetch_current_aqi()
                
                if aqi_data is None:
                    logger.warning("Failed to fetch AQI data")
                    return
                
                # Validate AQI value
                if aqi_data.get('aqi') is None:
                    logger.warning("AQI value is None, skipping storage")
                    return
                
                # Create pollution record
                pollution_record = PollutionData(
                    timestamp=aqi_data['timestamp'],
                    aqi=int(aqi_data['aqi']),
                    pm25=aqi_data.get('pm25'),
                    pm10=aqi_data.get('pm10'),
                    noise=None,  # API doesn't provide noise data
                    source='api'
                )
                
                db.session.add(pollution_record)
                db.session.commit()
                
                logger.info(f"Stored pollution data: AQI={pollution_record.aqi}")
                
                # Run alert checks after data insertion
                self._run_alert_checks()
                
            except Exception as e:
                logger.error(f"Error in fetch_and_store_aqi job: {e}")
                db.session.rollback()
    
    def _run_alert_checks(self):
        """Run all alert checks after new data is stored."""
        try:
            alert_config = {
                'AQI_ALERT_THRESHOLD': self.config.get('AQI_ALERT_THRESHOLD', 150),
                'AQI_ALERT_DURATION_MINUTES': self.config.get('AQI_ALERT_DURATION_MINUTES', 15),
                'NOISE_ALERT_THRESHOLD': self.config.get('NOISE_ALERT_THRESHOLD', 80),
                'NOISE_QUIET_HOURS_START': self.config.get('NOISE_QUIET_HOURS_START', 22),
                'NOISE_QUIET_HOURS_END': self.config.get('NOISE_QUIET_HOURS_END', 6),
            }
            
            alert_manager = get_alert_manager(alert_config)
            triggered_alerts = alert_manager.check_all_alerts()
            
            if triggered_alerts:
                logger.info(f"Triggered {len(triggered_alerts)} alert(s)")
                
        except Exception as e:
            logger.error(f"Error running alert checks: {e}")
    
    def start(self):
        """Start the scheduler."""
        try:
            # Add AQI fetch job - every 10 minutes
            self.scheduler.add_job(
                func=self.fetch_and_store_aqi,
                trigger=IntervalTrigger(
                    minutes=self.config.get('DATA_FETCH_INTERVAL_MINUTES', 10)
                ),
                id='fetch_aqi_data',
                name='Fetch AQI Data from AQICN',
                replace_existing=True,
                max_instances=1
            )
            
            # Start the scheduler
            self.scheduler.start()
            logger.info("Pollution scheduler started successfully")
            
            # Run initial fetch
            logger.info("Running initial AQI data fetch...")
            self.fetch_and_store_aqi()
            
        except Exception as e:
            logger.error(f"Error starting scheduler: {e}")
            raise
    
    def stop(self):
        """Stop the scheduler."""
        try:
            if self.scheduler.running:
                self.scheduler.shutdown(wait=False)
                logger.info("Pollution scheduler stopped")
        except Exception as e:
            logger.error(f"Error stopping scheduler: {e}")
    
    def get_status(self) -> Dict[str, Any]:
        """
        Get scheduler status information.
        
        Returns:
            Dictionary with scheduler status.
        """
        jobs = []
        for job in self.scheduler.get_jobs():
            jobs.append({
                'id': job.id,
                'name': job.name,
                'next_run_time': job.next_run_time.isoformat() if job.next_run_time else None,
                'trigger': str(job.trigger)
            })
        
        return {
            'running': self.scheduler.running,
            'jobs': jobs,
            'timezone': str(self.scheduler.timezone)
        }
    
    def trigger_fetch_now(self) -> bool:
        """
        Manually trigger an immediate AQI fetch.
        
        Returns:
            True if triggered successfully, False otherwise.
        """
        try:
            job = self.scheduler.get_job('fetch_aqi_data')
            if job:
                self.scheduler.modify_job('fetch_aqi_data', next_run_time=datetime.now())
                logger.info("Manual AQI fetch triggered")
                return True
            return False
        except Exception as e:
            logger.error(f"Error triggering manual fetch: {e}")
            return False


# Global instance
pollution_scheduler = None


def init_scheduler(app, config: Dict[str, Any]) -> PollutionScheduler:
    """
    Initialize and return the pollution scheduler.
    
    Args:
        app: Flask application instance.
        config: Configuration dictionary.
        
    Returns:
        PollutionScheduler instance.
    """
    global pollution_scheduler
    pollution_scheduler = PollutionScheduler(app, config)
    return pollution_scheduler


def get_scheduler() -> Optional[PollutionScheduler]:
    """Get the current scheduler instance."""
    return pollution_scheduler
