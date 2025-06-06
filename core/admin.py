from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import Parish, User, Category, Ministry, Event, EventException


@admin.register(Parish)
class ParishAdmin(admin.ModelAdmin):
    list_display = ('name', 'phone_number', 'website_url')
    search_fields = ('name', 'address')


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ('username', 'full_name', 'email', 'role', 'status', 'associated_parish')
    list_filter = ('role', 'status', 'associated_parish')
    search_fields = ('username', 'full_name', 'email')
    
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Hogtown Catholic Info', {
            'fields': ('full_name', 'associated_parish', 'role', 'status')
        }),
    )
    
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('Hogtown Catholic Info', {
            'fields': ('full_name', 'associated_parish', 'role', 'status')
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
