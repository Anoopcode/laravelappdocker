# Use the official PHP image as the base image
FROM php:8.1-fpm

# Set working directory
WORKDIR /var/www/html

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    zip \
    unzip \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    nginx \
    supervisor \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql mbstring exif pcntl bcmath gd zip

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Install Node.js and Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs \
    && npm install --global yarn

# Add a user for the application
RUN useradd -m -d /home/laraveluser laraveluser

# Copy application source
COPY . .

# Set ownership and permissions
RUN chown -R laraveluser:laraveluser /var/www/html \
    && chmod -R 777 /var/www/html /var/www/html/storage /var/www/html/bootstrap/cache

# Switch to the non-root user
USER laraveluser

# Install PHP dependencies
RUN composer install --optimize-autoloader

# Install Node.js dependencies and build assets for production
RUN yarn install --frozen-lockfile
RUN yarn prod

# Set up Laravel storage link, generate app key, and run migrations
RUN php artisan storage:link
RUN php artisan key:generate
RUN php artisan migrate --seed --force

# Switch back to root user to configure Nginx and Supervisor
USER root

# Nginx configuration
COPY default.conf /etc/nginx/conf.d/default.conf

# Copy the script to set the public IP in Nginx config
COPY set_nginx_ip.sh /usr/local/bin/set_nginx_ip.sh
RUN chmod +x /usr/local/bin/set_nginx_ip.sh

# Run the script to update Nginx configuration with the EC2 public IP
RUN /usr/local/bin/set_nginx_ip.sh

# Supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose ports
EXPOSE 80

# Start supervisord to run both PHP-FPM and Nginx
CMD ["/usr/bin/supervisord"]
