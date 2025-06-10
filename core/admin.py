from django.conf import settings
from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.core.mail import send_mail
from django.db import transaction
from django.template.loader import render_to_string
from django.utils.html import format_html

from .models import Category, Event, EventException, Ministry, Parish, User


@admin.register(Parish)
class ParishAdmin(admin.ModelAdmin):
    list_display = ("name", "phone_number", "website_url")
    search_fields = ("name", "address")


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = (
        "username",
        "full_name",
        "email",
        "role",
        "colored_status",
        "email_status",
        "associated_parish",
        "date_joined",
    )
    list_filter = (
        "role",
        "status",
        "approval_email_sent",
        "rejection_email_sent",
        "associated_parish",
        "date_joined",
    )
    search_fields = ("username", "full_name", "email")
    actions = [
        "approve_users",
        "reject_users",
        "retry_approval_emails",
        "retry_rejection_emails",
    ]

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        # Show pending users first
        return qs.order_by("status", "-date_joined")

    def colored_status(self, obj):
        colors = {"pending": "orange", "approved": "green", "rejected": "red"}
        return format_html(
            '<span style="color: {}; font-weight: bold;">{}</span>',
            colors.get(obj.status, "black"),
            obj.get_status_display(),
        )

    colored_status.short_description = "Status"

    def email_status(self, obj):
        if obj.status == "approved":
            if obj.approval_email_sent:
                return format_html('<span style="color: green;">✓ Sent</span>')
            else:
                return format_html('<span style="color: red;">✗ Failed</span>')
        elif obj.status == "rejected":
            if obj.rejection_email_sent:
                return format_html('<span style="color: green;">✓ Sent</span>')
            else:
                return format_html('<span style="color: red;">✗ Failed</span>')
        else:
            return "-"

    email_status.short_description = "Email Status"

    def approve_users(self, request, queryset):
        pending_users = queryset.filter(status="pending")
        if not pending_users.exists():
            self.message_user(request, "No pending users selected.", messages.WARNING)
            return

        approved_count = 0
        skipped_count = 0
        email_failures = 0
        successfully_updated_users = []

        # First, update user statuses (critical operation)
        for user in pending_users:
            try:
                with transaction.atomic():
                    # Use select_for_update to lock user record and prevent race conditions
                    user_to_update = User.objects.select_for_update().get(id=user.id)

                    # Double-check status after acquiring lock
                    if user_to_update.status != "pending":
                        skipped_count += 1
                        continue

                    user_to_update.status = "approved"
                    user_to_update.approval_email_sent = False  # Reset email status
                    user_to_update.email_failure_reason = ""  # Clear previous failure
                    user_to_update.save()
                    approved_count += 1
                    successfully_updated_users.append(user_to_update)

            except User.DoesNotExist:
                # User was deleted by another admin
                skipped_count += 1
                continue
            except Exception as e:
                self.message_user(
                    request,
                    f"Error processing user {user.username}: {e}",
                    messages.ERROR,
                )
                skipped_count += 1
                continue

        # Then, send notification emails (non-critical operation)
        for user_to_update in successfully_updated_users:
            try:
                context = {
                    "user": user_to_update,
                    "login_url": request.build_absolute_uri("/login/"),
                }
                subject = render_to_string(
                    "core/emails/approval_subject.txt", context
                ).strip()
                message = render_to_string("core/emails/approval_body.txt", context)

                send_mail(
                    subject=subject,
                    message=message,
                    from_email=settings.DEFAULT_FROM_EMAIL,
                    recipient_list=[user_to_update.email],
                    fail_silently=False,
                )

                # Mark email as successfully sent
                user_to_update.approval_email_sent = True
                user_to_update.email_failure_reason = ""
                user_to_update.save()

            except Exception as e:
                email_failures += 1
                # Record the failure
                user_to_update.approval_email_sent = False
                user_to_update.email_failure_reason = str(e)
                user_to_update.save()

                self.message_user(
                    request,
                    f"User approved but email failed for {user_to_update.email}: {e}",
                    messages.WARNING,
                )

        # Build success message
        message = f"Successfully approved {approved_count} users."
        if email_failures == 0 and approved_count > 0:
            message += " All notification emails sent successfully."
        elif email_failures > 0:
            message += f" {email_failures} notification emails failed (can be retried)."
        if skipped_count > 0:
            message += f" Skipped {skipped_count} users (already processed or deleted)."

        self.message_user(request, message, messages.SUCCESS)

    approve_users.short_description = "Approve selected users"

    def reject_users(self, request, queryset):
        pending_users = queryset.filter(status="pending")
        if not pending_users.exists():
            self.message_user(request, "No pending users selected.", messages.WARNING)
            return

        rejected_count = 0
        skipped_count = 0
        email_failures = 0
        successfully_updated_users = []

        # First, update user statuses (critical operation)
        for user in pending_users:
            try:
                with transaction.atomic():
                    # Use select_for_update to lock user record and prevent race conditions
                    user_to_update = User.objects.select_for_update().get(id=user.id)

                    # Double-check status after acquiring lock
                    if user_to_update.status != "pending":
                        skipped_count += 1
                        continue

                    user_to_update.status = "rejected"
                    user_to_update.rejection_email_sent = False  # Reset email status
                    user_to_update.email_failure_reason = ""  # Clear previous failure
                    user_to_update.save()
                    rejected_count += 1
                    successfully_updated_users.append(user_to_update)

            except User.DoesNotExist:
                # User was deleted by another admin
                skipped_count += 1
                continue
            except Exception as e:
                self.message_user(
                    request,
                    f"Error processing user {user.username}: {e}",
                    messages.ERROR,
                )
                skipped_count += 1
                continue

        # Then, send notification emails (non-critical operation)
        for user_to_update in successfully_updated_users:
            try:
                context = {"user": user_to_update}
                subject = render_to_string(
                    "core/emails/rejection_subject.txt", context
                ).strip()
                message = render_to_string("core/emails/rejection_body.txt", context)

                send_mail(
                    subject=subject,
                    message=message,
                    from_email=settings.DEFAULT_FROM_EMAIL,
                    recipient_list=[user_to_update.email],
                    fail_silently=False,
                )

                # Mark email as successfully sent
                user_to_update.rejection_email_sent = True
                user_to_update.email_failure_reason = ""
                user_to_update.save()

            except Exception as e:
                email_failures += 1
                # Record the failure
                user_to_update.rejection_email_sent = False
                user_to_update.email_failure_reason = str(e)
                user_to_update.save()

                self.message_user(
                    request,
                    f"User rejected but email failed for {user_to_update.email}: {e}",
                    messages.WARNING,
                )

        # Build success message
        message = f"Successfully rejected {rejected_count} users."
        if email_failures == 0 and rejected_count > 0:
            message += " All notification emails sent successfully."
        elif email_failures > 0:
            message += f" {email_failures} notification emails failed (can be retried)."
        if skipped_count > 0:
            message += f" Skipped {skipped_count} users (already processed or deleted)."

        self.message_user(request, message, messages.SUCCESS)

    reject_users.short_description = "Reject selected users"

    def retry_approval_emails(self, request, queryset):
        approved_users = queryset.filter(status="approved", approval_email_sent=False)
        if not approved_users.exists():
            self.message_user(
                request,
                "No approved users with failed emails selected.",
                messages.WARNING,
            )
            return

        success_count = 0
        failure_count = 0

        for user in approved_users:
            try:
                context = {
                    "user": user,
                    "login_url": request.build_absolute_uri("/login/"),
                }
                subject = render_to_string(
                    "core/emails/approval_subject.txt", context
                ).strip()
                message = render_to_string("core/emails/approval_body.txt", context)

                send_mail(
                    subject=subject,
                    message=message,
                    from_email=settings.DEFAULT_FROM_EMAIL,
                    recipient_list=[user.email],
                    fail_silently=False,
                )

                # Mark email as successfully sent
                user.approval_email_sent = True
                user.email_failure_reason = ""
                user.save()
                success_count += 1

            except Exception as e:
                failure_count += 1
                # Record the failure
                user.email_failure_reason = str(e)
                user.save()

                self.message_user(
                    request,
                    f"Email retry failed for {user.email}: {e}",
                    messages.WARNING,
                )

        message = f"Retried {success_count + failure_count} approval emails."
        if success_count > 0:
            message += f" {success_count} succeeded."
        if failure_count > 0:
            message += f" {failure_count} failed."

        self.message_user(request, message, messages.SUCCESS)

    retry_approval_emails.short_description = "Retry failed approval emails"

    def retry_rejection_emails(self, request, queryset):
        rejected_users = queryset.filter(status="rejected", rejection_email_sent=False)
        if not rejected_users.exists():
            self.message_user(
                request,
                "No rejected users with failed emails selected.",
                messages.WARNING,
            )
            return

        success_count = 0
        failure_count = 0

        for user in rejected_users:
            try:
                context = {"user": user}
                subject = render_to_string(
                    "core/emails/rejection_subject.txt", context
                ).strip()
                message = render_to_string("core/emails/rejection_body.txt", context)

                send_mail(
                    subject=subject,
                    message=message,
                    from_email=settings.DEFAULT_FROM_EMAIL,
                    recipient_list=[user.email],
                    fail_silently=False,
                )

                # Mark email as successfully sent
                user.rejection_email_sent = True
                user.email_failure_reason = ""
                user.save()
                success_count += 1

            except Exception as e:
                failure_count += 1
                # Record the failure
                user.email_failure_reason = str(e)
                user.save()

                self.message_user(
                    request,
                    f"Email retry failed for {user.email}: {e}",
                    messages.WARNING,
                )

        message = f"Retried {success_count + failure_count} rejection emails."
        if success_count > 0:
            message += f" {success_count} succeeded."
        if failure_count > 0:
            message += f" {failure_count} failed."

        self.message_user(request, message, messages.SUCCESS)

    retry_rejection_emails.short_description = "Retry failed rejection emails"

    fieldsets = BaseUserAdmin.fieldsets + (
        (
            "Hogtown Catholic Info",
            {
                "fields": (
                    "full_name",
                    "associated_parish",
                    "requested_ministry_details",
                    "role",
                    "status",
                )
            },
        ),
        (
            "Email Notifications",
            {
                "fields": (
                    "approval_email_sent",
                    "rejection_email_sent",
                    "email_failure_reason",
                ),
                "classes": ("collapse",),
            },
        ),
    )

    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        (
            "Hogtown Catholic Info",
            {
                "fields": (
                    "full_name",
                    "associated_parish",
                    "requested_ministry_details",
                    "role",
                    "status",
                )
            },
        ),
    )


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ("name",)
    search_fields = ("name",)


@admin.register(Ministry)
class MinistryAdmin(admin.ModelAdmin):
    list_display = ("name", "owner_user", "associated_parish")
    list_filter = ("associated_parish", "categories")
    search_fields = ("name", "description")
    filter_horizontal = ("categories",)


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ("title", "associated_ministry", "is_recurring", "get_event_time")
    list_filter = ("is_recurring", "associated_ministry__associated_parish")
    search_fields = ("title", "description", "location")

    fieldsets = (
        (
            "Basic Information",
            {
                "fields": (
                    "associated_ministry",
                    "title",
                    "description",
                    "location",
                    "is_recurring",
                )
            },
        ),
        (
            "Ad-hoc Event Times",
            {
                "fields": ("start_datetime", "end_datetime"),
                "classes": ("collapse",),
            },
        ),
        (
            "Recurring Event Details",
            {
                "fields": (
                    "series_start_date",
                    "series_end_date",
                    "start_time_of_day",
                    "end_time_of_day",
                    "recurrence_rule",
                ),
                "classes": ("collapse",),
            },
        ),
    )

    def get_event_time(self, obj):
        if obj.is_recurring:
            return f"Recurring: {obj.start_time_of_day} - {obj.end_time_of_day}"
        else:
            return f"{obj.start_datetime} - {obj.end_datetime}"

    get_event_time.short_description = "Event Time"


@admin.register(EventException)
class EventExceptionAdmin(admin.ModelAdmin):
    list_display = ("event", "original_occurrence_date", "status", "new_start_datetime")
    list_filter = ("status", "event__associated_ministry__associated_parish")
    search_fields = ("event__title",)
