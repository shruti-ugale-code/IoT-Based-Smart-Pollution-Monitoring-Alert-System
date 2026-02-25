"""
WSGI entry point for production deployment with Gunicorn.
"""

from app import create_app, start_scheduler

# Create application instance
application = create_app()
app = application

# Start scheduler for background jobs
scheduler = start_scheduler()


def on_starting(server):
    """Called just before the master process is initialized."""
    pass


def on_exit(server):
    """Called just before exiting Gunicorn."""
    if scheduler:
        scheduler.stop()
