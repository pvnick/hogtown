from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.core.mail import send_mail
from django.conf import settings
from django.contrib import messages
from django.utils.html import format_html
from django.template.loader import render_to_string
from .models import Parish, User, Category, Ministry, Event, EventException


@admin.register(Parish)
class ParishAdmin(admin.ModelAdmin):
    list_display = ('name', 'phone_number', 'website_url')
    search_fields = ('name', 'address')


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ('username', 'full_name', 'email', 'role', 'colored_status', 'associated_parish', 'date_joined')
    list_filter = ('role', 'status', 'associated_parish', 'date_joined')
    search_fields = ('username', 'full_name', 'email')
    actions = ['approve_users', 'reject_users']
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        # Show pending users first
        return qs.order_by('status', '-date_joined')
    
    def colored_status(self, obj):
        colors = {
            'pending': 'orange',
            'approved': 'green',
            'rejected': 'red'
        }
        return format_html(
            '<span style="color: {}; font-weight: bold;">{}</span>',
            colors.get(obj.status, 'black'),
            obj.get_status_display()
        )
    colored_status.short_description = 'Status'
    
    def approve_users(self, request, queryset):
        pending_users = queryset.filter(status='pending')
        if not pending_users.exists():
            self.message_user(request, "No pending users selected.", messages.WARNING)
            return
            
        approved_count = 0
        for user in pending_users:
            user.status = 'approved'
            user.save()
            
            # Send approval email
            try:
                context = {
                    'user': user,
                    'login_url': request.build_absolute_uri('/login/')
                }
                subject = render_to_string('core/emails/approval_subject.txt', context).strip()
                message = render_to_string('core/emails/approval_body.txt', context)
                
                send_mail(
                    subject=subject,
                    message=message,
                    from_email=settings.DEFAULT_FROM_EMAIL,
                    recipient_list=[user.email],
                    fail_silently=False,
                )
                approved_count += 1
            except Exception as e:
                self.message_user(request, f"Error sending email to {user.email}: {e}", messages.ERROR)
        
        self.message_user(request, f"Successfully approved {approved_count} users and sent notification emails.", messages.SUCCESS)
    approve_users.short_description = "Approve selected users"
    
    def reject_users(self, request, queryset):
        pending_users = queryset.filter(status='pending')
        if not pending_users.exists():
            self.message_user(request, "No pending users selected.", messages.WARNING)
            return
            
        rejected_count = 0
        for user in pending_users:
            user.status = 'rejected'
            user.save()
            
            # Send rejection email
            try:
                context = {'user': user}
                subject = render_to_string('core/emails/rejection_subject.txt', context).strip()
                message = render_to_string('core/emails/rejection_body.txt', context)
                
                send_mail(
                    subject=subject,
                    message=message,
                    from_email=settings.DEFAULT_FROM_EMAIL,
                    recipient_list=[user.email],
                    fail_silently=False,
                )
                rejected_count += 1
            except Exception as e:
                self.message_user(request, f"Error sending email to {user.email}: {e}", messages.ERROR)
        
        self.message_user(request, f"Successfully rejected {rejected_count} users and sent notification emails.", messages.SUCCESS)
    reject_users.short_description = "Reject selected users"
    
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Hogtown Catholic Info', {
            'fields': ('full_name', 'associated_parish', 'requested_ministry_details', 'role', 'status')
        }),
    )
    
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('Hogtown Catholic Info', {
            'fields': ('full_name', 'associated_parish', 'requested_ministry_details', 'role', 'status')
        }),
    )


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ('name',)
    search_fields = ('name',)


@admin.register(Ministry)
class MinistryAdmin(admin.ModelAdmin):
    list_display = ('name', 'owner_user', 'associated_parish')
    list_filter = ('associated_parish', 'categories')
    search_fields = ('name', 'description')
    filter_horizontal = ('categories',)


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ('title', 'associated_ministry', 'is_recurring', 'get_event_time')
    list_filter = ('is_recurring', 'associated_ministry__associated_parish')
    search_fields = ('title', 'description', 'location')
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('associated_ministry', 'title', 'description', 'location', 'is_recurring')
        }),
        ('Ad-hoc Event Times', {
            'fields': ('start_datetime', 'end_datetime'),
            'classes': ('collapse',),
        }),
        ('Recurring Event Details', {
            'fields': ('series_start_date', 'series_end_date', 'start_time_of_day', 'end_time_of_day', 'recurrence_rule'),
            'classes': ('collapse',),
        }),
    )
    
    def get_event_time(self, obj):
        if obj.is_recurring:
            return f"Recurring: {obj.start_time_of_day} - {obj.end_time_of_day}"
        else:
            return f"{obj.start_datetime} - {obj.end_datetime}"
    get_event_time.short_description = 'Event Time'


@admin.register(EventException)
class EventExceptionAdmin(admin.ModelAdmin):
    list_display = ('event', 'original_occurrence_date', 'status', 'new_start_datetime')
    list_filter = ('status', 'event__associated_ministry__associated_parish')
    search_fields = ('event__title',)
