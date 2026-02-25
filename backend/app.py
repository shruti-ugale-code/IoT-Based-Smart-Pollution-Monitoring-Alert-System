"""
Main Flask application for Smart Pollution Monitoring & Alert System.
Production-ready backend with REST API endpoints, background jobs, and ML predictions.
"""

import logging
import os
import sys
from datetime import datetime
from functools import wraps

from flask import Flask, jsonify, request
from flask_cors import CORS

from config import get_config
from models import db, PollutionData, Alert, DeviceToken, init_db
from statistics import statistics_engine
from alerts import get_alert_manager, init_firebase
from ml_model import get_aqi_predictor
from scheduler import init_scheduler, get_scheduler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


def create_app(config_class=None):
    """
    Application factory for creating Flask app instance.
    
    Args:
        config_class: Configuration class to use. Defaults to environment-based config.
        
    Returns:
        Configured Flask application instance.
    """
    app = Flask(__name__)
    
    # Load configuration
    if config_class is None:
        config_class = get_config()
    app.config.from_object(config_class)
    
    # Configure logging level
    log_level = getattr(logging, app.config.get('LOG_LEVEL', 'INFO'))
    logging.getLogger().setLevel(log_level)
    
    # Initialize extensions
    init_db(app)
    
    # Enable CORS
    CORS(app, origins=app.config.get('CORS_ORIGINS', '*'))
    
    # Initialize Firebase
    firebase_creds = app.config.get('FIREBASE_CREDENTIALS_PATH')
    init_firebase(firebase_creds)
    
    # Initialize alert manager
    alert_config = {
        'AQI_ALERT_THRESHOLD': app.config.get('AQI_ALERT_THRESHOLD', 150),
        'AQI_ALERT_DURATION_MINUTES': app.config.get('AQI_ALERT_DURATION_MINUTES', 15),
        'NOISE_ALERT_THRESHOLD': app.config.get('NOISE_ALERT_THRESHOLD', 80),
        'NOISE_QUIET_HOURS_START': app.config.get('NOISE_QUIET_HOURS_START', 22),
        'NOISE_QUIET_HOURS_END': app.config.get('NOISE_QUIET_HOURS_END', 6),
    }
    get_alert_manager(alert_config)
    
    # Initialize ML model
    ml_model_path = app.config.get('ML_MODEL_PATH')
    get_aqi_predictor(ml_model_path)
    
    # Register blueprints/routes
    register_routes(app)
    
    # Register error handlers
    register_error_handlers(app)
    
    logger.info(f"Application created with config: {config_class.__name__}")
    return app


def register_error_handlers(app):
    """Register global error handlers."""
    
    @app.errorhandler(400)
    def bad_request(error):
        return jsonify({
            'success': False,
            'error': 'Bad Request',
            'message': str(error.description) if hasattr(error, 'description') else 'Invalid request'
        }), 400
    
    @app.errorhandler(404)
    def not_found(error):
        return jsonify({
            'success': False,
            'error': 'Not Found',
            'message': 'The requested resource was not found'
        }), 404
    
    @app.errorhandler(500)
    def internal_error(error):
        logger.error(f"Internal server error: {error}")
        return jsonify({
            'success': False,
            'error': 'Internal Server Error',
            'message': 'An unexpected error occurred'
        }), 500


def validate_json(*required_fields):
    """Decorator to validate JSON request body."""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not request.is_json:
                return jsonify({
                    'success': False,
                    'error': 'Content-Type must be application/json'
                }), 400
            
            data = request.get_json()
            if data is None:
                return jsonify({
                    'success': False,
                    'error': 'Invalid JSON body'
                }), 400
            
            missing_fields = [field for field in required_fields if field not in data]
            if missing_fields:
                return jsonify({
                    'success': False,
                    'error': f'Missing required fields: {", ".join(missing_fields)}'
                }), 400
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator


def register_routes(app):
    """Register all API routes."""
    
    # ==================== Health Check ====================
    
    @app.route('/health', methods=['GET'])
    def health_check():
        """Health check endpoint."""
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'version': '1.0.0'
        })
    
    # ==================== Pollution Data Endpoints ====================
    
    @app.route('/upload', methods=['POST'])
    @validate_json('aqi')
    def upload_pollution_data():
        """
        Upload pollution data from API or sensor.
        
        Expected JSON:
        {
            "source": "api" or "sensor",
            "timestamp": "ISO format datetime (optional)",
            "aqi": integer value,
            "pm25": float value (optional),
            "pm10": float value (optional),
            "noise": float value (optional)
        }
        """
        try:
            data = request.get_json()
            
            # Validate AQI value
            aqi = data.get('aqi')
            if not isinstance(aqi, (int, float)) or aqi < 0 or aqi > 500:
                return jsonify({
                    'success': False,
                    'error': 'AQI must be a number between 0 and 500'
                }), 400
            
            # Validate source
            source = data.get('source', 'sensor')
            if source not in ['api', 'sensor']:
                return jsonify({
                    'success': False,
                    'error': 'Source must be "api" or "sensor"'
                }), 400
            
            # Parse timestamp
            timestamp_str = data.get('timestamp')
            if timestamp_str:
                try:
                    timestamp = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                except ValueError:
                    return jsonify({
                        'success': False,
                        'error': 'Invalid timestamp format. Use ISO 8601 format.'
                    }), 400
            else:
                timestamp = datetime.utcnow()
            
            # Create record
            pollution_record = PollutionData(
                timestamp=timestamp,
                aqi=int(aqi),
                pm25=data.get('pm25'),
                pm10=data.get('pm10'),
                noise=data.get('noise'),
                source=source
            )
            
            db.session.add(pollution_record)
            db.session.commit()
            
            # Run alert checks
            alert_manager = get_alert_manager()
            triggered_alerts = alert_manager.check_all_alerts()
            
            logger.info(f"Pollution data uploaded: AQI={aqi}, source={source}")
            
            return jsonify({
                'success': True,
                'message': 'Pollution data uploaded successfully',
                'data': pollution_record.to_dict(),
                'alerts_triggered': len(triggered_alerts)
            }), 201
            
        except Exception as e:
            logger.error(f"Error uploading pollution data: {e}")
            db.session.rollback()
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    @app.route('/current', methods=['GET'])
    def get_current_pollution():
        """Get the latest pollution record."""
        try:
            latest = PollutionData.get_latest()
            
            if not latest:
                return jsonify({
                    'success': True,
                    'data': None,
                    'message': 'No pollution data available'
                })
            
            return jsonify({
                'success': True,
                'data': latest.to_dict()
            })
            
        except Exception as e:
            logger.error(f"Error getting current pollution: {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    @app.route('/history', methods=['GET'])
    def get_pollution_history():
        """Get pollution data for the last 24 hours."""
        try:
            hours = request.args.get('hours', 24, type=int)
            hours = min(max(hours, 1), 168)  # Limit between 1 and 168 hours (7 days)
            
            records = PollutionData.get_history(hours=hours)
            
            return jsonify({
                'success': True,
                'data': [record.to_dict() for record in records],
                'count': len(records),
                'hours': hours
            })
            
        except Exception as e:
            logger.error(f"Error getting pollution history: {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    # ==================== Alert Endpoints ====================
    
    @app.route('/alerts', methods=['GET'])
    def get_alerts():
        """Get active alerts."""
        try:
            include_resolved = request.args.get('include_resolved', 'false').lower() == 'true'
            
            if include_resolved:
                alerts = Alert.get_recent_alerts(hours=24)
            else:
                alerts = Alert.get_active_alerts()
            
            return jsonify({
                'success': True,
                'data': [alert.to_dict() for alert in alerts],
                'count': len(alerts)
            })
            
        except Exception as e:
            logger.error(f"Error getting alerts: {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    @app.route('/alerts/<int:alert_id>/resolve', methods=['POST'])
    def resolve_alert(alert_id):
        """Manually resolve an alert."""
        try:
            alert_manager = get_alert_manager()
            success = alert_manager.resolve_alert(alert_id)
            
            if success:
                return jsonify({
                    'success': True,
                    'message': f'Alert {alert_id} resolved successfully'
                })
            else:
                return jsonify({
                    'success': False,
                    'error': f'Alert {alert_id} not found'
                }), 404
                
        except Exception as e:
            logger.error(f"Error resolving alert: {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    # ==================== Prediction Endpoint ====================
    
    @app.route('/prediction', methods=['GET'])
    def get_prediction():
        """Get AQI prediction for the next hour."""
        try:
            predictor = get_aqi_predictor()
            prediction = predictor.predict()
            
            return jsonify({
                'success': True,
                'data': prediction
            })
            
        except Exception as e:
            logger.error(f"Error getting prediction: {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    # ==================== Statistics Endpoints ====================
    
    @app.route('/statistics', methods=['GET'])
    def get_statistics():
        """Get comprehensive pollution statistics."""
        try:
            stats = statistics_engine.get_full_statistics()
            
            return jsonify({
                'success': True,
                'data': stats
            })
            
        except Exception as e:
            logger.error(f"Error getting statistics: {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    @app.route('/statistics/hourly', methods=['GET'])
    def get_hourly_statistics():
        """Get hourly breakdown of pollution data."""
        try:
            hours = request.args.get('hours', 24, type=int)
            hourly_data = statistics_engine.get_hourly_breakdown(hours=hours)
            
            return jsonify({
                'success': True,
                'data': hourly_data,
                'count': len(hourly_data)
            })
            
        except Exception as e:
            logger.error(f"Error getting hourly statistics: {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    # ==================== Device Token Endpoint ====================
    
    @app.route('/register-device', methods=['POST'])
    @validate_json('token')
    def register_device():
        """Register a Firebase device token for push notifications."""
        try:
            data = request.get_json()
            token = data.get('token')
            
            if not token or len(token) < 10:
                return jsonify({
                    'success': False,
                    'error': 'Invalid device token'
                }), 400
            
            device_token = DeviceToken.register_token(token)
            
            logger.info(f"Device token registered: {token[:20]}...")
            
            return jsonify({
                'success': True,
                'message': 'Device registered successfully',
                'data': device_token.to_dict()
            }), 201
            
        except Exception as e:
            logger.error(f"Error registering device: {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    @app.route('/unregister-device', methods=['POST'])
    @validate_json('token')
    def unregister_device():
        """Unregister a Firebase device token."""
        try:
            data = request.get_json()
            token = data.get('token')
            
            success = DeviceToken.deactivate_token(token)
            
            if success:
                return jsonify({
                    'success': True,
                    'message': 'Device unregistered successfully'
                })
            else:
                return jsonify({
                    'success': False,
                    'error': 'Token not found'
                }), 404
                
        except Exception as e:
            logger.error(f"Error unregistering device: {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    # ==================== Scheduler Endpoints ====================
    
    @app.route('/scheduler/status', methods=['GET'])
    def get_scheduler_status():
        """Get scheduler status."""
        try:
            scheduler = get_scheduler()
            if scheduler:
                return jsonify({
                    'success': True,
                    'data': scheduler.get_status()
                })
            else:
                return jsonify({
                    'success': True,
                    'data': {'running': False, 'message': 'Scheduler not initialized'}
                })
                
        except Exception as e:
            logger.error(f"Error getting scheduler status: {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    @app.route('/scheduler/trigger', methods=['POST'])
    def trigger_fetch():
        """Manually trigger AQI data fetch."""
        try:
            scheduler = get_scheduler()
            if scheduler:
                success = scheduler.trigger_fetch_now()
                return jsonify({
                    'success': success,
                    'message': 'Fetch triggered' if success else 'Failed to trigger fetch'
                })
            else:
                return jsonify({
                    'success': False,
                    'error': 'Scheduler not initialized'
                }), 400
                
        except Exception as e:
            logger.error(f"Error triggering fetch: {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    # ==================== ML Model Endpoints ====================
    
    @app.route('/model/info', methods=['GET'])
    def get_model_info():
        """Get ML model information."""
        try:
            predictor = get_aqi_predictor()
            return jsonify({
                'success': True,
                'data': predictor.get_model_info()
            })
            
        except Exception as e:
            logger.error(f"Error getting model info: {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    @app.route('/model/train', methods=['POST'])
    def train_model():
        """Manually trigger model training."""
        try:
            predictor = get_aqi_predictor()
            result = predictor.train()
            
            return jsonify({
                'success': result.get('success', False),
                'data': result
            })
            
        except Exception as e:
            logger.error(f"Error training model: {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500


# Create application instance
app = create_app()


def start_scheduler():
    """Start the background scheduler."""
    global app
    config = {
        'AQICN_API_KEY': app.config.get('AQICN_API_KEY'),
        'AQICN_CITY': app.config.get('AQICN_CITY'),
        'AQICN_BASE_URL': app.config.get('AQICN_BASE_URL'),
        'SCHEDULER_TIMEZONE': app.config.get('SCHEDULER_TIMEZONE'),
        'DATA_FETCH_INTERVAL_MINUTES': app.config.get('DATA_FETCH_INTERVAL_MINUTES'),
        'AQI_ALERT_THRESHOLD': app.config.get('AQI_ALERT_THRESHOLD'),
        'AQI_ALERT_DURATION_MINUTES': app.config.get('AQI_ALERT_DURATION_MINUTES'),
        'NOISE_ALERT_THRESHOLD': app.config.get('NOISE_ALERT_THRESHOLD'),
        'NOISE_QUIET_HOURS_START': app.config.get('NOISE_QUIET_HOURS_START'),
        'NOISE_QUIET_HOURS_END': app.config.get('NOISE_QUIET_HOURS_END'),
    }
    
    scheduler = init_scheduler(app, config)
    scheduler.start()
    return scheduler


if __name__ == '__main__':
    # Start scheduler in development mode
    scheduler_instance = start_scheduler()
    
    try:
        # Run Flask development server
        app.run(
            host='0.0.0.0',
            port=int(os.environ.get('PORT', 5000)),
            debug=app.config.get('DEBUG', False),
            use_reloader=False  # Disable reloader to prevent scheduler duplicate
        )
    finally:
        # Cleanup scheduler on shutdown
        if scheduler_instance:
            scheduler_instance.stop()
