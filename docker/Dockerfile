# Use the Bitnami WordPress image as the base
FROM bitnami/wordpress:latest

USER root

# Copy custom script into the container
COPY custom-script.sh /custom-script.sh

# Ensure the script is executable
RUN chmod +x /custom-script.sh

# Run the custom script
CMD ["/custom-script.sh"]