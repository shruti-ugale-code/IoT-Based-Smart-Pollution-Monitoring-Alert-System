"""
Database models for Smart Pollution Monitoring & Alert System.
Defines SQLAlchemy ORM models for pollution data, alerts, and device tokens.
"""

from datetime import datetime
from flask_sqlalchemy import SQLAlchemy



db = SQLAlchemy()


class PollutionData(db.Model):
    """Model for storing pollution data records."""
    
    __tablename__ = 'pollution_data'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    timestamp = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, index=True)
    aqi = db.Column(db.Integer, nullable=False)
    pm25 = db.Column(db.Float, nullable=True)
    pm10 = db.Column(db.Float, nullable=True)
    noise = db.Column(db.Float, nullable=True)
    source = db.Column(db.String(20), nullable=False, default='api')  # 'api' or 'sensor'
    
    def __repr__(self):
        return f'<PollutionData id={self.id} aqi={self.aqi} timestamp={self.timestamp}>'
    
    def to_dict(self):
        """Convert model instance to dictionary."""
        return {
            'id': self.id,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None,
            'aqi': self.aqi,
            'pm25': self.pm25,
            'pm10': self.pm10,
            'noise': self.noise,
            'source': self.source
        }
    
    @classmethod
    def get_latest(cls):
        """Get the most recent pollution data record."""
        return cls.query.order_by(cls.timestamp.desc()).first()
    
    @classmethod
    def get_history(cls, hours=24):
        """Get pollution data for the last specified hours."""
        from datetime import timedelta
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        return cls.query.filter(
            cls.timestamp >= cutoff_time
        ).order_by(cls.timestamp.desc()).all()
    
    @classmethod
    def get_data_for_period(cls, start_time, end_time=None):
        """Get pollution data for a specific time period."""
        query = cls.query.filter(cls.timestamp >= start_time)
        if end_time:
            query = query.filter(cls.timestamp <= end_time)
        return query.order_by(cls.timestamp.asc()).all()


class Alert(db.Model):
    """Model for storing pollution and noise alerts."""
    
    __tablename__ = 'alerts'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    timestamp = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, index=True)
    alert_type = db.Column(db.String(50), nullable=False)  # 'high_aqi', 'high_noise'
    message = db.Column(db.Text, nullable=False)
    status = db.Column(db.String(20), nullable=False, default='Active')  # 'Active' or 'Resolved'
    resolved_at = db.Column(db.DateTime, nullable=True)
    
    def __repr__(self):
        return f'<Alert id={self.id} type={self.alert_type} status={self.status}>'
    
    def to_dict(self):
        """Convert model instance to dictionary."""
        return {
            'id': self.id,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None,
            'alert_type': self.alert_type,
            'message': self.message,
            'status': self.status,
            'resolved_at': self.resolved_at.isoformat() if self.resolved_at else None
        }
    
    @classmethod
    def get_active_alerts(cls):
        """Get all active alerts."""
        return cls.query.filter_by(status='Active').order_by(cls.timestamp.desc()).all()
    
    @classmethod
    def get_recent_alerts(cls, hours=24):
        """Get alerts from the last specified hours."""
        from datetime import timedelta
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        return cls.query.filter(
            cls.timestamp >= cutoff_time
        ).order_by(cls.timestamp.desc()).all()
    
    def resolve(self):
        """Mark alert as resolved."""
        self.status = 'Resolved'
        self.resolved_at = datetime.utcnow()
        db.session.commit()


class DeviceToken(db.Model):
    """Model for storing Firebase device tokens for push notifications."""
    
    __tablename__ = 'device_tokens'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    token = db.Column(db.String(500), nullable=False, unique=True, index=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    
    def __repr__(self):
        return f'<DeviceToken id={self.id} active={self.is_active}>'
    
    def to_dict(self):
        """Convert model instance to dictionary."""
        return {
            'id': self.id,
            'token': self.token[:20] + '...' if len(self.token) > 20 else self.token,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'is_active': self.is_active
        }
    
    @classmethod
    def get_active_tokens(cls):
        """Get all active device tokens."""
        return cls.query.filter_by(is_active=True).all()
    
    @classmethod
    def register_token(cls, token):
        """Register a new device token or reactivate an existing one."""
        existing = cls.query.filter_by(token=token).first()
        if existing:
            existing.is_active = True
            db.session.commit()
            return existing
        else:
            new_token = cls(token=token)
            db.session.add(new_token)
            db.session.commit()
            return new_token
    
    @classmethod
    def deactivate_token(cls, token):
        """Deactivate a device token."""
        existing = cls.query.filter_by(token=token).first()
        if existing:
            existing.is_active = False
            db.session.commit()
            return True
        return False


def init_db(app):
    """Initialize database with the Flask app."""
    db.init_app(app)
    with app.app_context():
        db.create_all()
