"""
Statistics engine for Smart Pollution Monitoring & Alert System.
Provides statistical analysis of pollution data including averages, trends, and peak hours.
"""

import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any

import pandas as pd

from models import PollutionData, db

logger = logging.getLogger(__name__)


class StatisticsEngine:
    """Engine for calculating pollution statistics."""
    
    def __init__(self):
        """Initialize the statistics engine."""
        pass
    
    def get_daily_average_aqi(self, date: Optional[datetime] = None) -> Optional[float]:
        """
        Calculate the average AQI for a specific day.
        
        Args:
            date: The date to calculate average for. Defaults to today.
            
        Returns:
            Average AQI value or None if no data available.
        """
        try:
            if date is None:
                date = datetime.utcnow()
            
            start_of_day = date.replace(hour=0, minute=0, second=0, microsecond=0)
            end_of_day = start_of_day + timedelta(days=1)
            
            records = PollutionData.get_data_for_period(start_of_day, end_of_day)
            
            if not records:
                logger.warning(f"No data available for daily average on {date.date()}")
                return None
            
            total_aqi = sum(record.aqi for record in records)
            average = total_aqi / len(records)
            
            logger.debug(f"Daily average AQI for {date.date()}: {average:.2f}")
            return round(average, 2)
            
        except Exception as e:
            logger.error(f"Error calculating daily average AQI: {e}")
            return None
    
    def get_weekly_average_aqi(self, end_date: Optional[datetime] = None) -> Optional[float]:
        """
        Calculate the average AQI for the last 7 days.
        
        Args:
            end_date: The end date for the week. Defaults to today.
            
        Returns:
            Average AQI value or None if no data available.
        """
        try:
            if end_date is None:
                end_date = datetime.utcnow()
            
            start_date = end_date - timedelta(days=7)
            
            records = PollutionData.get_data_for_period(start_date, end_date)
            
            if not records:
                logger.warning("No data available for weekly average")
                return None
            
            total_aqi = sum(record.aqi for record in records)
            average = total_aqi / len(records)
            
            logger.debug(f"Weekly average AQI: {average:.2f}")
            return round(average, 2)
            
        except Exception as e:
            logger.error(f"Error calculating weekly average AQI: {e}")
            return None
    
    def get_peak_pollution_hour(self, date: Optional[datetime] = None) -> Optional[Dict[str, Any]]:
        """
        Find the hour with the highest average AQI for a specific day.
        
        Args:
            date: The date to analyze. Defaults to today.
            
        Returns:
            Dictionary with peak hour info or None if no data available.
        """
        try:
            if date is None:
                date = datetime.utcnow()
            
            start_of_day = date.replace(hour=0, minute=0, second=0, microsecond=0)
            end_of_day = start_of_day + timedelta(days=1)
            
            records = PollutionData.get_data_for_period(start_of_day, end_of_day)
            
            if not records:
                logger.warning(f"No data available for peak hour analysis on {date.date()}")
                return None
            
            # Group by hour and calculate average
            hourly_data = {}
            for record in records:
                hour = record.timestamp.hour
                if hour not in hourly_data:
                    hourly_data[hour] = []
                hourly_data[hour].append(record.aqi)
            
            # Find peak hour
            peak_hour = None
            peak_aqi = 0
            
            for hour, aqi_values in hourly_data.items():
                avg_aqi = sum(aqi_values) / len(aqi_values)
                if avg_aqi > peak_aqi:
                    peak_aqi = avg_aqi
                    peak_hour = hour
            
            if peak_hour is not None:
                result = {
                    'hour': peak_hour,
                    'hour_formatted': f"{peak_hour:02d}:00 - {peak_hour:02d}:59",
                    'average_aqi': round(peak_aqi, 2),
                    'date': date.date().isoformat()
                }
                logger.debug(f"Peak pollution hour: {result}")
                return result
            
            return None
            
        except Exception as e:
            logger.error(f"Error finding peak pollution hour: {e}")
            return None
    
    def detect_trend(self) -> Dict[str, Any]:
        """
        Detect the AQI trend by comparing current AQI with yesterday's average.
        
        Returns:
            Dictionary with trend information.
        """
        try:
            # Get current AQI
            latest = PollutionData.get_latest()
            if not latest:
                return {
                    'trend': 'Unknown',
                    'description': 'Insufficient data for trend analysis',
                    'current_aqi': None,
                    'yesterday_average': None
                }
            
            current_aqi = latest.aqi
            
            # Get yesterday's average
            yesterday = datetime.utcnow() - timedelta(days=1)
            yesterday_avg = self.get_daily_average_aqi(yesterday)
            
            if yesterday_avg is None:
                return {
                    'trend': 'Unknown',
                    'description': 'Insufficient historical data for trend analysis',
                    'current_aqi': current_aqi,
                    'yesterday_average': None
                }
            
            # Determine trend
            if current_aqi > yesterday_avg:
                trend = 'Increasing'
                description = f'Current AQI ({current_aqi}) is higher than yesterday\'s average ({yesterday_avg:.1f})'
            elif current_aqi < yesterday_avg:
                trend = 'Decreasing'
                description = f'Current AQI ({current_aqi}) is lower than yesterday\'s average ({yesterday_avg:.1f})'
            else:
                trend = 'Stable'
                description = f'Current AQI ({current_aqi}) is similar to yesterday\'s average ({yesterday_avg:.1f})'
            
            result = {
                'trend': trend,
                'description': description,
                'current_aqi': current_aqi,
                'yesterday_average': round(yesterday_avg, 2),
                'change_percentage': round(((current_aqi - yesterday_avg) / yesterday_avg) * 100, 2) if yesterday_avg else 0
            }
            
            logger.debug(f"Trend detected: {result}")
            return result
            
        except Exception as e:
            logger.error(f"Error detecting trend: {e}")
            return {
                'trend': 'Error',
                'description': f'Error analyzing trend: {str(e)}',
                'current_aqi': None,
                'yesterday_average': None
            }
    
    def get_full_statistics(self) -> Dict[str, Any]:
        """
        Get comprehensive statistics including all metrics.
        
        Returns:
            Dictionary with all statistics.
        """
        try:
            today = datetime.utcnow()
            
            stats = {
                'daily_average_aqi': self.get_daily_average_aqi(today),
                'weekly_average_aqi': self.get_weekly_average_aqi(today),
                'peak_pollution_hour': self.get_peak_pollution_hour(today),
                'trend': self.detect_trend(),
                'generated_at': datetime.utcnow().isoformat()
            }
            
            logger.info("Generated full statistics report")
            return stats
            
        except Exception as e:
            logger.error(f"Error generating full statistics: {e}")
            return {
                'error': str(e),
                'generated_at': datetime.utcnow().isoformat()
            }
    
    def get_hourly_breakdown(self, hours: int = 24) -> List[Dict[str, Any]]:
        """
        Get hourly AQI breakdown for the specified number of hours.
        
        Args:
            hours: Number of hours to analyze.
            
        Returns:
            List of hourly statistics.
        """
        try:
            records = PollutionData.get_history(hours=hours)
            
            if not records:
                return []
            
            # Convert to DataFrame for easier analysis
            data = [{
                'timestamp': r.timestamp,
                'aqi': r.aqi,
                'pm25': r.pm25,
                'pm10': r.pm10,
                'noise': r.noise
            } for r in records]
            
            df = pd.DataFrame(data)
            df['hour'] = df['timestamp'].dt.floor('h')
            
            # Group by hour and calculate statistics
            hourly_stats = []
            for hour, group in df.groupby('hour'):
                hourly_stats.append({
                    'hour': hour.isoformat(),
                    'avg_aqi': round(group['aqi'].mean(), 2),
                    'max_aqi': int(group['aqi'].max()),
                    'min_aqi': int(group['aqi'].min()),
                    'avg_pm25': round(group['pm25'].mean(), 2) if group['pm25'].notna().any() else None,
                    'avg_pm10': round(group['pm10'].mean(), 2) if group['pm10'].notna().any() else None,
                    'avg_noise': round(group['noise'].mean(), 2) if group['noise'].notna().any() else None,
                    'readings_count': len(group)
                })
            
            return sorted(hourly_stats, key=lambda x: x['hour'], reverse=True)
            
        except Exception as e:
            logger.error(f"Error getting hourly breakdown: {e}")
            return []


# Singleton instance
statistics_engine = StatisticsEngine()
