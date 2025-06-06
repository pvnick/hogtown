from django import forms
from django.contrib.auth.forms import UserCreationForm

from .fields import ProsopoField
from .models import Parish, User


class MinistryLeaderRegistrationForm(UserCreationForm):
    full_name = forms.CharField(
        max_length=200, widget=forms.TextInput(attrs={"class": "form-control"})
    )
    email = forms.EmailField(widget=forms.EmailInput(attrs={"class": "form-control"}))
    associated_parish = forms.ModelChoiceField(
        queryset=Parish.objects.all(),
        widget=forms.Select(attrs={"class": "form-control"}),
        empty_label="Select your parish...",
    )
    requested_ministry_details = forms.CharField(
        widget=forms.Textarea(
            attrs={
                "class": "form-control",
                "rows": 4,
                "placeholder": "Please describe the ministry you lead or wish to create, including its purpose and activities.",
            }
        ),
        help_text="Please describe the ministry you lead or wish to create, including its purpose and activities.",
    )
    captcha = ProsopoField()

    class Meta:
        model = User
        fields = (
            "username",
            "email",
            "full_name",
            "associated_parish",
            "requested_ministry_details",
            "password1",
            "password2",
        )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Add Bootstrap classes to password fields
        self.fields["username"].widget.attrs.update({"class": "form-control"})
        self.fields["password1"].widget.attrs.update({"class": "form-control"})
        self.fields["password2"].widget.attrs.update({"class": "form-control"})

        # Update field labels and help texts
        self.fields["username"].help_text = None
        self.fields["password1"].help_text = None
        self.fields[
            "password2"
        ].help_text = "Enter the same password as before, for verification."

    def save(self, commit=True):
        user = super().save(commit=False)
        user.email = self.cleaned_data["email"]
        user.full_name = self.cleaned_data["full_name"]
        user.associated_parish = self.cleaned_data["associated_parish"]
        user.requested_ministry_details = self.cleaned_data[
            "requested_ministry_details"
        ]
        user.role = "leader"
        user.status = "pending"
        if commit:
            user.save()
        return user
