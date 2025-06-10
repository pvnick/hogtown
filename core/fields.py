import requests

from django import forms
from django.conf import settings
from django.core.exceptions import ValidationError


class ProsopoWidget(forms.Widget):
    template_name = "core/widgets/prosopo.html"

    def __init__(self, attrs=None):
        default_attrs = {"class": "procaptcha"}
        if attrs:
            default_attrs.update(attrs)
        super().__init__(default_attrs)

    def render(self, name, value, attrs=None, renderer=None):
        if attrs is None:
            attrs = {}
        attrs["data-sitekey"] = getattr(settings, "PROSOPO_SITE_KEY", "")
        return super().render(name, value, attrs, renderer)


class ProsopoField(forms.CharField):
    widget = ProsopoWidget

    def __init__(self, *args, **kwargs):
        kwargs.setdefault("required", True)
        kwargs.setdefault("label", "")
        super().__init__(*args, **kwargs)

    def validate(self, value):
        super().validate(value)
        if value:
            self._verify_token(value)

    def _verify_token(self, token):
        """Verify the Prosopo token with the API"""
        secret_key = getattr(settings, "PROSOPO_SECRET_KEY", "")
        verify_url = getattr(
            settings, "PROSOPO_VERIFY_URL", "https://api.prosopo.io/siteverify"
        )

        if not secret_key:
            raise ValidationError("Prosopo secret key not configured")

        try:
            response = requests.post(
                verify_url, json={"secret": secret_key, "token": token}, timeout=10
            )

            if response.status_code != 200:
                raise ValidationError("Failed to verify captcha")

            result = response.json()
            if not result.get("success", False):
                raise ValidationError("Captcha verification failed")

        except requests.RequestException:
            raise ValidationError("Failed to verify captcha - network error")
        except (ValueError, KeyError):
            raise ValidationError("Invalid captcha response")
