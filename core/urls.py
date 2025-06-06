from django.contrib.auth import views as auth_views
from django.urls import path

from . import views

urlpatterns = [
    # Public views
    path("", views.parish_directory, name="parish_directory"),
    path("parish/<int:parish_id>/", views.parish_detail, name="parish_detail"),
    path("ministry/<int:ministry_id>/", views.ministry_detail, name="ministry_detail"),
    path("calendar/", views.event_calendar, name="event_calendar"),
    path("api/calendar-events/", views.get_calendar_events, name="calendar_events_api"),
    # Authentication
    path(
        "login/",
        auth_views.LoginView.as_view(template_name="core/login.html"),
        name="login",
    ),
    path("logout/", auth_views.LogoutView.as_view(), name="logout"),
    path("register/", views.register_ministry_leader, name="register"),
    path(
        "registration-success/", views.registration_success, name="registration_success"
    ),
    # Ministry Leader Portal
    path("portal/", views.ministry_portal, name="ministry_portal"),
    path(
        "ministry/create/", views.MinistryCreateView.as_view(), name="ministry_create"
    ),
    path(
        "ministry/<int:pk>/edit/",
        views.MinistryUpdateView.as_view(),
        name="ministry_edit",
    ),
    path("event/create/", views.EventCreateView.as_view(), name="event_create"),
    path("event/<int:pk>/edit/", views.EventUpdateView.as_view(), name="event_edit"),
    path(
        "event/<int:event_id>/occurrence/<str:occurrence_date>/action/",
        views.event_occurrence_action,
        name="event_occurrence_action",
    ),
]
