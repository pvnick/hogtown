from datetime import datetime

from dateutil.rrule import rrulestr

from django.conf import settings
from django.contrib.auth.decorators import login_required
from django.contrib.auth.mixins import LoginRequiredMixin
from django.core.mail import send_mail
from django.db import models
from django.http import JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.template.loader import render_to_string
from django.urls import reverse_lazy
from django.views.generic import CreateView, UpdateView

from .forms import MinistryLeaderRegistrationForm
from .models import Category, Event, EventException, Ministry, Parish, User


def parish_directory(request):
    parishes = Parish.objects.all().order_by("name")
    return render(request, "core/parish_directory.html", {"parishes": parishes})


def parish_detail(request, parish_id):
    parish = get_object_or_404(Parish, pk=parish_id)
    ministries = Ministry.objects.filter(associated_parish=parish).order_by("name")
    return render(
        request, "core/parish_detail.html", {"parish": parish, "ministries": ministries}
    )


def ministry_detail(request, ministry_id):
    ministry = get_object_or_404(Ministry, pk=ministry_id)
    events = Event.objects.filter(associated_ministry=ministry)
    return render(
        request, "core/ministry_detail.html", {"ministry": ministry, "events": events}
    )


def event_calendar(request):
    categories = Category.objects.all()
    parishes = Parish.objects.all()
    return render(
        request,
        "core/event_calendar.html",
        {"categories": categories, "parishes": parishes},
    )


def get_calendar_events(request):
    start_date = request.GET.get("start")
    end_date = request.GET.get("end")

    if not start_date or not end_date:
        return JsonResponse({"events": []})

    start = datetime.fromisoformat(start_date.replace("Z", "+00:00")).date()
    end = datetime.fromisoformat(end_date.replace("Z", "+00:00")).date()

    events = []

    # Get ad-hoc events
    adhoc_events = Event.objects.filter(
        is_recurring=False, start_datetime__date__range=[start, end]
    ).select_related("associated_ministry__associated_parish")

    for event in adhoc_events:
        events.append(
            {
                "id": f"adhoc_{event.id}",
                "title": event.title,
                "start": event.start_datetime.isoformat(),
                "end": event.end_datetime.isoformat(),
                "description": event.description,
                "location": event.location,
                "ministry": event.associated_ministry.name,
                "parish": event.associated_ministry.associated_parish.name,
            }
        )

    # Get recurring events
    recurring_events = (
        Event.objects.filter(
            is_recurring=True,
            series_start_date__lte=end,
        )
        .filter(
            models.Q(series_end_date__isnull=True)
            | models.Q(series_end_date__gte=start)
        )
        .select_related("associated_ministry__associated_parish")
    )

    for event in recurring_events:
        if event.recurrence_rule:
            try:
                # Parse the recurrence rule
                dtstart = datetime.combine(
                    event.series_start_date, event.start_time_of_day
                )
                rrule = rrulestr(event.recurrence_rule, dtstart=dtstart)

                # Get occurrences in the date range
                occurrences = rrule.between(
                    datetime.combine(start, datetime.min.time()),
                    datetime.combine(end, datetime.max.time()),
                    inc=True,
                )

                # Get exceptions for this event
                exceptions = EventException.objects.filter(
                    event=event, original_occurrence_date__range=[start, end]
                )
                exception_dict = {
                    exc.original_occurrence_date: exc for exc in exceptions
                }

                for occurrence in occurrences:
                    occurrence_date = occurrence.date()

                    # Check if this occurrence has an exception
                    if occurrence_date in exception_dict:
                        exception = exception_dict[occurrence_date]
                        if exception.status == "cancelled":
                            continue
                        elif exception.status == "rescheduled":
                            events.append(
                                {
                                    "id": f"recurring_{event.id}_{occurrence_date}",
                                    "title": f"{event.title} (Rescheduled)",
                                    "start": exception.new_start_datetime.isoformat(),
                                    "end": exception.new_end_datetime.isoformat(),
                                    "description": event.description,
                                    "location": event.location,
                                    "ministry": event.associated_ministry.name,
                                    "parish": event.associated_ministry.associated_parish.name,
                                }
                            )
                            continue

                    # Normal occurrence
                    start_dt = datetime.combine(
                        occurrence_date, event.start_time_of_day
                    )
                    end_dt = datetime.combine(occurrence_date, event.end_time_of_day)

                    events.append(
                        {
                            "id": f"recurring_{event.id}_{occurrence_date}",
                            "title": event.title,
                            "start": start_dt.isoformat(),
                            "end": end_dt.isoformat(),
                            "description": event.description,
                            "location": event.location,
                            "ministry": event.associated_ministry.name,
                            "parish": event.associated_ministry.associated_parish.name,
                        }
                    )

            except Exception:
                # Log error in production
                continue

    return JsonResponse({"events": events})


@login_required
def ministry_portal(request):
    user_ministries = Ministry.objects.filter(owner_user=request.user)
    return render(request, "core/ministry_portal.html", {"ministries": user_ministries})


class MinistryCreateView(LoginRequiredMixin, CreateView):
    model = Ministry
    fields = ["associated_parish", "name", "description", "contact_info", "categories"]
    template_name = "core/ministry_form.html"
    success_url = reverse_lazy("ministry_portal")

    def form_valid(self, form):
        form.instance.owner_user = self.request.user
        return super().form_valid(form)


class MinistryUpdateView(LoginRequiredMixin, UpdateView):
    model = Ministry
    fields = ["associated_parish", "name", "description", "contact_info", "categories"]
    template_name = "core/ministry_form.html"
    success_url = reverse_lazy("ministry_portal")

    def get_queryset(self):
        return Ministry.objects.filter(owner_user=self.request.user)


class EventCreateView(LoginRequiredMixin, CreateView):
    model = Event
    fields = [
        "associated_ministry",
        "title",
        "description",
        "location",
        "is_recurring",
        "start_datetime",
        "end_datetime",
        "series_start_date",
        "series_end_date",
        "start_time_of_day",
        "end_time_of_day",
        "recurrence_rule",
    ]
    template_name = "core/event_form.html"
    success_url = reverse_lazy("ministry_portal")

    def get_form(self, form_class=None):
        form = super().get_form(form_class)
        # Limit ministry choices to user's ministries
        form.fields["associated_ministry"].queryset = Ministry.objects.filter(
            owner_user=self.request.user
        )
        return form


class EventUpdateView(LoginRequiredMixin, UpdateView):
    model = Event
    fields = [
        "associated_ministry",
        "title",
        "description",
        "location",
        "is_recurring",
        "start_datetime",
        "end_datetime",
        "series_start_date",
        "series_end_date",
        "start_time_of_day",
        "end_time_of_day",
        "recurrence_rule",
    ]
    template_name = "core/event_form.html"
    success_url = reverse_lazy("ministry_portal")

    def get_queryset(self):
        return Event.objects.filter(associated_ministry__owner_user=self.request.user)

    def get_form(self, form_class=None):
        form = super().get_form(form_class)
        form.fields["associated_ministry"].queryset = Ministry.objects.filter(
            owner_user=self.request.user
        )
        return form


@login_required
def event_occurrence_action(request, event_id, occurrence_date):
    """Handle actions on individual event occurrences (cancel/reschedule)"""
    event = get_object_or_404(
        Event, pk=event_id, associated_ministry__owner_user=request.user
    )

    if not event.is_recurring:
        return JsonResponse(
            {"error": "This action is only available for recurring events"}, status=400
        )

    from datetime import datetime

    try:
        occurrence_date_obj = datetime.strptime(occurrence_date, "%Y-%m-%d").date()
    except ValueError:
        return JsonResponse({"error": "Invalid date format"}, status=400)

    if request.method == "POST":
        action = request.POST.get("action")

        if action == "cancel":
            exception, created = EventException.objects.get_or_create(
                event=event,
                original_occurrence_date=occurrence_date_obj,
                defaults={"status": "cancelled"},
            )
            if not created:
                exception.status = "cancelled"
                exception.new_start_datetime = None
                exception.new_end_datetime = None
                exception.save()

            return JsonResponse({"success": True, "action": "cancelled"})

        elif action == "reschedule":
            new_start = request.POST.get("new_start_datetime")
            new_end = request.POST.get("new_end_datetime")

            if not new_start or not new_end:
                return JsonResponse(
                    {"error": "New start and end times required"}, status=400
                )

            try:
                new_start_dt = datetime.fromisoformat(new_start.replace("Z", "+00:00"))
                new_end_dt = datetime.fromisoformat(new_end.replace("Z", "+00:00"))
            except ValueError:
                return JsonResponse({"error": "Invalid datetime format"}, status=400)

            exception, created = EventException.objects.get_or_create(
                event=event,
                original_occurrence_date=occurrence_date_obj,
                defaults={
                    "status": "rescheduled",
                    "new_start_datetime": new_start_dt,
                    "new_end_datetime": new_end_dt,
                },
            )
            if not created:
                exception.status = "rescheduled"
                exception.new_start_datetime = new_start_dt
                exception.new_end_datetime = new_end_dt
                exception.save()

            return JsonResponse({"success": True, "action": "rescheduled"})

        elif action == "restore":
            try:
                exception = EventException.objects.get(
                    event=event, original_occurrence_date=occurrence_date_obj
                )
                exception.delete()
                return JsonResponse({"success": True, "action": "restored"})
            except EventException.DoesNotExist:
                return JsonResponse(
                    {"error": "No exception found to restore"}, status=404
                )

    return JsonResponse({"error": "Invalid request"}, status=400)


def register_ministry_leader(request):
    if request.method == "POST":
        # Get the Prosopo token from the form
        prosopo_token = request.POST.get("procaptcha-response", "")

        # Create a modified POST data with the token for our captcha field
        post_data = request.POST.copy()
        post_data["captcha"] = prosopo_token

        form = MinistryLeaderRegistrationForm(post_data)
        if form.is_valid():
            user = form.save()

            # Send notification emails to all administrators
            admin_users = User.objects.filter(role="admin")
            for admin in admin_users:
                try:
                    context = {
                        "user": user,
                        "admin_url": request.build_absolute_uri("/admin/core/user/"),
                    }
                    subject = render_to_string(
                        "core/emails/admin_notification_subject.txt", context
                    ).strip()
                    message = render_to_string(
                        "core/emails/admin_notification_body.txt", context
                    )

                    send_mail(
                        subject=subject,
                        message=message,
                        from_email=settings.DEFAULT_FROM_EMAIL,
                        recipient_list=[admin.email],
                        fail_silently=True,
                    )
                except Exception:
                    # Log error in production, but don't fail the registration
                    pass

            return redirect("registration_success")
    else:
        form = MinistryLeaderRegistrationForm()

    return render(request, "core/register.html", {"form": form})


def registration_success(request):
    return render(request, "core/registration_success.html")
