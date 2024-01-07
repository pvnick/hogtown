# Use the Bitnami WordPress image as the base
FROM bitnami/wordpress:latest

# Copy custom script into the container
COPY docker/custom-script.sh /custom-script.sh

# Ensure the script is executable
RUN chmod +x /custom-script.sh

# Run the custom script
CMD ["/custom-script.sh"]