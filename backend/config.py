"""
Configuration module for Smart Pollution Monitoring & Alert System.
Contains all configuration settings for the application.
"""

import os
from datetime import timedelta


class Config:
    """Base configuration class."""
    
    # Flask settings
    SECRET_KEY = os.environ.get('SECRET_KEY', 'your-secret-key-change-in-production')
    DEBUG = False
    TESTING = False
    
    # Database settings
    SQLALCHEMY_DATABASE_URI = os.environ.get(
        'DATABASE_URL', 
        'sqlite:///pollution_monitoring.db'
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_pre_ping': True,
        'pool_recycle': 300,
    }
    
    # CORS settings
    CORS_ORIGINS = os.environ.get('CORS_ORIGINS', '*')
    
    # AQICN API settings
    AQICN_API_KEY = os.environ.get('AQICN_API_KEY', 'demo')
    AQICN_CITY = os.environ.get('AQICN_CITY', 'pune')
    AQICN_BASE_URL = 'https://api.waqi.info'
    
    # Firebase settings
    FIREBASE_CREDENTIALS_PATH = os.environ.get(
        'FIREBASE_CREDENTIALS_PATH', 
        'firebase-credentials.json'
    )
    
    # Alert thresholds
    AQI_ALERT_THRESHOLD = 150
    AQI_ALERT_DURATION_MINUTES = 15
    NOISE_ALERT_THRESHOLD = 80
    NOISE_QUIET_HOURS_START = 22  # 10 PM
    NOISE_QUIET_HOURS_END = 6     # 6 AM
    
    # Scheduler settings
    SCHEDULER_API_ENABLED = True
    SCHEDULER_TIMEZONE = os.environ.get('SCHEDULER_TIMEZONE', 'Asia/Kolkata')
    DATA_FETCH_INTERVAL_MINUTES = 10
    
    # Logging settings
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
    LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    
    # ML Model settings
    ML_MODEL_PATH = os.environ.get('ML_MODEL_PATH', 'aqi_prediction_model.joblib')
    PREDICTION_FEATURES = ['hour', 'day_of_week', 'prev_aqi_1', 'prev_aqi_2', 'prev_aqi_3']


class DevelopmentConfig(Config):
    """Development configuration."""
    DEBUG = True
    LOG_LEVEL = 'DEBUG'


class ProductionConfig(Config):
    """Production configuration."""
    DEBUG = False
    
    # Use PostgreSQL in production (Render provides DATABASE_URL)
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL', '').replace(
        'postgres://', 'postgresql://'
    ) or Config.SQLALCHEMY_DATABASE_URI


class TestingConfig(Config):
    """Testing configuration."""
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'


def get_config():
    """Get configuration based on environment."""
    env = os.environ.get('FLASK_ENV', 'development')
    config_map = {
        'development': DevelopmentConfig,
        'production': ProductionConfig,
        'testing': TestingConfig,
    }
    return config_map.get(env, DevelopmentConfig)
