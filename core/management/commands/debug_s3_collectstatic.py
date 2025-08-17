import importlib.util
import os

from django.conf import settings
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Debug static files and S3 configuration"

    def handle(self, *args, **options):
        self.stdout.write("=== Debugging Django Static Files and S3 Settings ===")
        self.stdout.write(f"Python Version: {os.sys.version}")
        self.stdout.write(
            f"Django Version: {importlib.import_module('django').__version__}"
        )

        # Static files settings
        self.stdout.write("\nStatic Files Settings:")
        # Check for new STORAGES configuration (Django 5.2+)
        storages = getattr(settings, "STORAGES", {})
        if "staticfiles" in storages:
            self.stdout.write(
                f"STORAGES['staticfiles']['BACKEND']: {storages['staticfiles'].get('BACKEND', 'Not set')}"
            )
        else:
            self.stdout.write(
                f"STATICFILES_STORAGE: {getattr(settings, 'STATICFILES_STORAGE', 'Not set')}"
            )
        self.stdout.write(f"STATIC_ROOT: {getattr(settings, 'STATIC_ROOT', 'Not set')}")
        self.stdout.write(f"STATIC_URL: {getattr(settings, 'STATIC_URL', 'Not set')}")
        self.stdout.write(
            f"DEFAULT_FILE_STORAGE: {getattr(settings, 'DEFAULT_FILE_STORAGE', 'Not set')}"
        )

        # S3-related settings
        self.stdout.write("\nAWS S3 Settings:")
        self.stdout.write(
            f"AWS_STORAGE_BUCKET_NAME: {os.environ.get('AWS_STORAGE_BUCKET_NAME', 'Not set')}"
        )
        self.stdout.write(
            f"AWS_S3_REGION_NAME: {os.environ.get('AWS_S3_REGION_NAME', 'Not set')}"
        )
        self.stdout.write(
            f"AWS_ACCESS_KEY_ID: {os.environ.get('AWS_ACCESS_KEY_ID', 'Not set')[:4]}**** (masked)"
        )
        self.stdout.write(
            f"AWS_SECRET_ACCESS_KEY: {'**** (masked)' if os.environ.get('AWS_SECRET_ACCESS_KEY') else 'Not set'}"
        )
        self.stdout.write(
            f"AWS_S3_CUSTOM_DOMAIN: {getattr(settings, 'AWS_S3_CUSTOM_DOMAIN', 'Not set')}"
        )
        self.stdout.write(
            f"AWS_DEFAULT_ACL: {getattr(settings, 'AWS_DEFAULT_ACL', 'Not set')}"
        )
        self.stdout.write(
            f"AWS_LOCATION: {getattr(settings, 'AWS_LOCATION', 'Not set')}"
        )

        # Check for conditional logic flags
        self.stdout.write("\nEnvironment Flags:")
        self.stdout.write(f"DEBUG: {settings.DEBUG}")
        self.stdout.write(f"USE_S3: {os.environ.get('USE_S3', 'Not set')}")

        # Check if django-storages and boto3 are installed
        self.stdout.write("\nPackage Checks:")
        try:
            import storages

            self.stdout.write(f"django-storages Version: {storages.__version__}")
        except ImportError:
            self.stdout.write("django-storages: Not installed")
        try:
            import boto3

            self.stdout.write(f"boto3 Version: {boto3.__version__}")
        except ImportError:
            self.stdout.write("boto3: Not installed")

        # Test S3 connectivity
        self.stdout.write("\nTesting S3 Connectivity:")
        try:
            from storages.backends.s3boto3 import S3Boto3Storage

            storage = S3Boto3Storage()
            bucket_name = getattr(
                settings,
                "AWS_STORAGE_BUCKET_NAME",
                os.environ.get("AWS_STORAGE_BUCKET_NAME"),
            )
            if bucket_name:
                # Try listing objects to verify credentials and bucket access
                storage.connection.meta.client.list_objects_v2(
                    Bucket=bucket_name, MaxKeys=1
                )
                self.stdout.write(
                    f"S3 Connection: Successful (able to list objects in bucket {bucket_name})"
                )
            else:
                self.stdout.write(
                    "S3 Connection: Skipped (AWS_STORAGE_BUCKET_NAME not set)"
                )
        except Exception as e:
            self.stdout.write(f"S3 Connection: Failed - {str(e)}")
