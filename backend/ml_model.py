"""
Machine Learning module for Smart Pollution Monitoring & Alert System.
Provides AQI prediction using regression models and probable cause mapping.
"""

import logging
import os
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List, Tuple

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.linear_model import LinearRegression, Ridge
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
from sklearn.preprocessing import StandardScaler
import joblib

from models import PollutionData

logger = logging.getLogger(__name__)


class AQIPredictionModel:
    """Machine learning model for predicting AQI values."""
    
    # Probable causes mapping based on AQI levels and time of day
    PROBABLE_CAUSES = {
        'morning_rush': {
            'hours': (7, 10),
            'causes': ['Traffic', 'Vehicle emissions', 'Commuter vehicles']
        },
        'evening_rush': {
            'hours': (17, 20),
            'causes': ['Traffic', 'Vehicle emissions', 'Return commute']
        },
        'industrial': {
            'hours': (9, 17),
            'causes': ['Industrial activity', 'Construction', 'Manufacturing']
        },
        'night': {
            'hours': (22, 6),
            'causes': ['Temperature inversion', 'Dust settling', 'Low wind dispersal']
        },
        'default': {
            'causes': ['General pollution', 'Mixed sources', 'Urban activities']
        }
    }
    
    def __init__(self, model_path: Optional[str] = None):
        """
        Initialize the AQI prediction model.
        
        Args:
            model_path: Path to save/load the trained model.
        """
        self.model_path = model_path or 'aqi_prediction_model.joblib'
        self.scaler_path = self.model_path.replace('.joblib', '_scaler.joblib')
        self.model = None
        self.scaler = None
        self.is_trained = False
        self.feature_names = ['hour', 'day_of_week', 'prev_aqi_1', 'prev_aqi_2', 'prev_aqi_3']
        
        # Try to load existing model
        self._load_model()
    
    def _load_model(self) -> bool:
        """
        Load a previously trained model from disk.
        
        Returns:
            True if model loaded successfully, False otherwise.
        """
        try:
            if os.path.exists(self.model_path) and os.path.exists(self.scaler_path):
                self.model = joblib.load(self.model_path)
                self.scaler = joblib.load(self.scaler_path)
                self.is_trained = True
                logger.info(f"Model loaded from {self.model_path}")
                return True
            else:
                logger.info("No existing model found. Training required.")
                return False
        except Exception as e:
            logger.error(f"Error loading model: {e}")
            return False
    
    def _save_model(self) -> bool:
        """
        Save the trained model to disk.
        
        Returns:
            True if saved successfully, False otherwise.
        """
        try:
            if self.model is not None and self.scaler is not None:
                joblib.dump(self.model, self.model_path)
                joblib.dump(self.scaler, self.scaler_path)
                logger.info(f"Model saved to {self.model_path}")
                return True
            return False
        except Exception as e:
            logger.error(f"Error saving model: {e}")
            return False
    
    def _prepare_features(self, data: pd.DataFrame) -> Tuple[np.ndarray, np.ndarray]:
        """
        Prepare features for training or prediction.
        
        Args:
            data: DataFrame with pollution data.
            
        Returns:
            Tuple of (features, targets) as numpy arrays.
        """
        # Sort by timestamp
        data = data.sort_values('timestamp')
        
        # Create features
        features = []
        targets = []
        
        aqi_values = data['aqi'].values
        timestamps = data['timestamp'].values
        
        for i in range(3, len(data)):
            timestamp = pd.Timestamp(timestamps[i])
            
            feature_row = [
                timestamp.hour,                    # Hour of day
                timestamp.dayofweek,              # Day of week (0=Monday, 6=Sunday)
                aqi_values[i-1],                   # Previous AQI (t-1)
                aqi_values[i-2],                   # AQI at t-2
                aqi_values[i-3],                   # AQI at t-3
            ]
            
            features.append(feature_row)
            targets.append(aqi_values[i])
        
        return np.array(features), np.array(targets)
    
    def train(self, min_samples: int = 50) -> Dict[str, Any]:
        """
        Train the AQI prediction model using historical data.
        
        Args:
            min_samples: Minimum number of samples required for training.
            
        Returns:
            Dictionary with training results and metrics.
        """
        try:
            # Fetch historical data
            records = PollutionData.get_history(hours=168)  # Last 7 days
            
            if len(records) < min_samples:
                logger.warning(f"Insufficient data for training: {len(records)} < {min_samples}")
                return {
                    'success': False,
                    'error': f'Insufficient data. Need at least {min_samples} records, got {len(records)}'
                }
            
            # Convert to DataFrame
            data = pd.DataFrame([{
                'timestamp': r.timestamp,
                'aqi': r.aqi,
                'pm25': r.pm25,
                'pm10': r.pm10
            } for r in records])
            
            # Prepare features
            X, y = self._prepare_features(data)
            
            if len(X) < 10:
                return {
                    'success': False,
                    'error': 'Not enough sequential data points for training'
                }
            
            # Split data
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=0.2, random_state=42
            )
            
            # Scale features
            self.scaler = StandardScaler()
            X_train_scaled = self.scaler.fit_transform(X_train)
            X_test_scaled = self.scaler.transform(X_test)
            
            # Train model (using Gradient Boosting for better accuracy)
            self.model = GradientBoostingRegressor(
                n_estimators=100,
                max_depth=5,
                learning_rate=0.1,
                random_state=42
            )
            
            self.model.fit(X_train_scaled, y_train)
            
            # Evaluate model
            y_pred = self.model.predict(X_test_scaled)
            
            metrics = {
                'mse': float(mean_squared_error(y_test, y_pred)),
                'mae': float(mean_absolute_error(y_test, y_pred)),
                'rmse': float(np.sqrt(mean_squared_error(y_test, y_pred))),
                'r2_score': float(r2_score(y_test, y_pred))
            }
            
            # Save model
            self._save_model()
            self.is_trained = True
            
            logger.info(f"Model trained successfully. Metrics: {metrics}")
            
            return {
                'success': True,
                'samples_used': len(X),
                'train_samples': len(X_train),
                'test_samples': len(X_test),
                'metrics': metrics,
                'feature_importance': dict(zip(
                    self.feature_names, 
                    self.model.feature_importances_.tolist()
                ))
            }
            
        except Exception as e:
            logger.error(f"Error training model: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def predict(self) -> Dict[str, Any]:
        """
        Predict the next hour's AQI value.
        
        Returns:
            Dictionary with predicted AQI and probable cause.
        """
        try:
            # Check if model is trained
            if not self.is_trained:
                # Try to train with available data
                train_result = self.train(min_samples=20)
                if not train_result.get('success'):
                    # Fall back to simple prediction
                    return self._fallback_prediction()
            
            # Get recent data for prediction
            recent_records = PollutionData.query.order_by(
                PollutionData.timestamp.desc()
            ).limit(3).all()
            
            if len(recent_records) < 3:
                return self._fallback_prediction()
            
            # Prepare features for prediction
            current_time = datetime.utcnow()
            next_hour = current_time + timedelta(hours=1)
            
            feature_row = np.array([[
                next_hour.hour,
                next_hour.weekday(),
                recent_records[0].aqi,  # Most recent
                recent_records[1].aqi,
                recent_records[2].aqi,
            ]])
            
            # Scale features
            feature_scaled = self.scaler.transform(feature_row)
            
            # Make prediction
            predicted_aqi = self.model.predict(feature_scaled)[0]
            predicted_aqi = max(0, min(500, round(predicted_aqi)))  # Clamp to valid AQI range
            
            # Get probable cause
            probable_cause = self._get_probable_cause(next_hour.hour, predicted_aqi)
            
            result = {
                'predicted_aqi': int(predicted_aqi),
                'probable_cause': probable_cause,
                'prediction_time': next_hour.isoformat(),
                'confidence': self._get_confidence_level(predicted_aqi),
                'aqi_category': self._get_aqi_category(int(predicted_aqi))
            }
            
            logger.info(f"AQI prediction: {result}")
            return result
            
        except Exception as e:
            logger.error(f"Error making prediction: {e}")
            return self._fallback_prediction()
    
    def _fallback_prediction(self) -> Dict[str, Any]:
        """
        Provide a simple fallback prediction when ML model is unavailable.
        
        Returns:
            Dictionary with predicted AQI based on recent average.
        """
        try:
            recent_records = PollutionData.get_history(hours=3)
            
            if recent_records:
                avg_aqi = sum(r.aqi for r in recent_records) / len(recent_records)
                predicted_aqi = int(round(avg_aqi))
            else:
                predicted_aqi = 100  # Default moderate value
            
            next_hour = datetime.utcnow() + timedelta(hours=1)
            probable_cause = self._get_probable_cause(next_hour.hour, predicted_aqi)
            
            return {
                'predicted_aqi': predicted_aqi,
                'probable_cause': probable_cause,
                'prediction_time': next_hour.isoformat(),
                'confidence': 'Low (fallback prediction)',
                'aqi_category': self._get_aqi_category(predicted_aqi),
                'note': 'Using simple average due to insufficient training data'
            }
            
        except Exception as e:
            logger.error(f"Error in fallback prediction: {e}")
            return {
                'predicted_aqi': 100,
                'probable_cause': 'Unknown',
                'error': 'Unable to make prediction'
            }
    
    def _get_probable_cause(self, hour: int, aqi: int) -> str:
        """
        Determine the probable cause of pollution based on time and AQI level.
        
        Args:
            hour: Hour of the day (0-23).
            aqi: AQI value.
            
        Returns:
            String describing the probable cause.
        """
        import random
        
        # Check time-based causes
        for period, info in self.PROBABLE_CAUSES.items():
            if period == 'default':
                continue
                
            start_hour, end_hour = info['hours']
            
            # Handle night hours that cross midnight
            if start_hour > end_hour:  # e.g., (22, 6)
                if hour >= start_hour or hour < end_hour:
                    return random.choice(info['causes'])
            else:
                if start_hour <= hour < end_hour:
                    return random.choice(info['causes'])
        
        # Default causes based on AQI level
        if aqi > 200:
            return 'Severe pollution from multiple sources'
        elif aqi > 150:
            return 'High industrial and vehicular emissions'
        elif aqi > 100:
            return 'Moderate urban pollution'
        else:
            return random.choice(self.PROBABLE_CAUSES['default']['causes'])
    
    def _get_confidence_level(self, predicted_aqi: float) -> str:
        """
        Get confidence level description for the prediction.
        
        Args:
            predicted_aqi: The predicted AQI value.
            
        Returns:
            String describing confidence level.
        """
        if self.is_trained and hasattr(self.model, 'feature_importances_'):
            return 'High (trained model)'
        return 'Medium'
    
    def _get_aqi_category(self, aqi: int) -> str:
        """
        Get the AQI category description.
        
        Args:
            aqi: AQI value.
            
        Returns:
            Category description string.
        """
        if aqi <= 50:
            return 'Good'
        elif aqi <= 100:
            return 'Moderate'
        elif aqi <= 150:
            return 'Unhealthy for Sensitive Groups'
        elif aqi <= 200:
            return 'Unhealthy'
        elif aqi <= 300:
            return 'Very Unhealthy'
        else:
            return 'Hazardous'
    
    def get_model_info(self) -> Dict[str, Any]:
        """
        Get information about the current model.
        
        Returns:
            Dictionary with model information.
        """
        return {
            'is_trained': self.is_trained,
            'model_type': type(self.model).__name__ if self.model else None,
            'feature_names': self.feature_names,
            'model_path': self.model_path,
            'model_exists': os.path.exists(self.model_path)
        }


# Singleton instance
aqi_predictor = None


def get_aqi_predictor(model_path: Optional[str] = None) -> AQIPredictionModel:
    """Get or create the AQI predictor instance."""
    global aqi_predictor
    if aqi_predictor is None:
        aqi_predictor = AQIPredictionModel(model_path)
    return aqi_predictor
