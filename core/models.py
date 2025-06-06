from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.exceptions import ValidationError


class Parish(models.Model):
    name = models.CharField(max_length=200)
    address = models.TextField()
    website_url = models.URLField(blank=True, null=True)
    phone_number = models.CharField(max_length=20, blank=True)
    mass_schedule = models.TextField(blank=True)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name_plural = "parishes"


class User(AbstractUser):
    ROLE_CHOICES = [
        ('leader', 'Ministry Leader'),
        ('admin', 'Administrator'),
    ]
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
    ]
    
    full_name = models.CharField(max_length=200)
    associated_parish = models.ForeignKey(Parish, on_delete=models.CASCADE, null=True, blank=True)
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='leader')
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')

    def __str__(self):
        return f"{self.full_name} ({self.email})"


class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name_plural = "categories"


class Ministry(models.Model):
    owner_user = models.ForeignKey(User, on_delete=models.CASCADE)
    associated_parish = models.ForeignKey(Parish, on_delete=models.CASCADE)
    name = models.CharField(max_length=200)
    description = models.TextField()
    contact_info = models.TextField()
    categories = models.ManyToManyField(Category, blank=True)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name_plural = "ministries"


class Event(models.Model):
    associated_ministry = models.ForeignKey(Ministry, on_delete=models.CASCADE)
    title = models.CharField(max_length=200)
    description = models.TextField()
    location = models.CharField(max_length=300)
    is_recurring = models.BooleanField(default=False)
    
    # For ad-hoc events
    start_datetime = models.DateTimeField(null=True, blank=True)
    end_datetime = models.DateTimeField(null=True, blank=True)
    
    # For recurring events
    series_start_date = models.DateField(null=True, blank=True)
    series_end_date = models.DateField(null=True, blank=True)
    start_time_of_day = models.TimeField(null=True, blank=True)
    end_time_of_day = models.TimeField(null=True, blank=True)
    recurrence_rule = models.TextField(blank=True)

    def __str__(self):
        return self.title

    def clean(self):
        if self.is_recurring:
            if not all([self.series_start_date, self.start_time_of_day, self.end_time_of_day, self.recurrence_rule]):
                raise ValidationError("Recurring events must have series dates, times, and recurrence rule.")
        else:
            if not all([self.start_datetime, self.end_datetime]):
                raise ValidationError("Ad-hoc events must have start and end datetime.")


class EventException(models.Model):
    STATUS_CHOICES = [
        ('cancelled', 'Cancelled'),
        ('rescheduled', 'Rescheduled'),
    ]
    
    event = models.ForeignKey(Event, on_delete=models.CASCADE)
    original_occurrence_date = models.DateField()
    status = models.CharField(max_length=12, choices=STATUS_CHOICES)
    new_start_datetime = models.DateTimeField(null=True, blank=True)
    new_end_datetime = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.event.title} - {self.original_occurrence_date} ({self.status})"

    def clean(self):
        if self.status == 'rescheduled' and not all([self.new_start_datetime, self.new_end_datetime]):
            raise ValidationError("Rescheduled events must have new start and end datetime.")

    class Meta:
        unique_together = ('event', 'original_occurrence_date')
