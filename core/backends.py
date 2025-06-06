from django.contrib.auth.backends import ModelBackend
from django.contrib.auth import get_user_model

User = get_user_model()


class ApprovedUserBackend(ModelBackend):
    """
    Custom authentication backend that only allows approved users to log in.
    """
    
    def authenticate(self, request, username=None, password=None, **kwargs):
        user = super().authenticate(request, username, password, **kwargs)
        
        if user and user.status != 'approved':
            return None  # Don't allow login for non-approved users
            
        return user