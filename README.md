# Project description
This project is a full-stack web application that uses Rust for the backend and React for the frontend. The application will be deployed on Heroku and will use PostgreSQL as the database, Redis for caching, RabbitMQ for message brokering, and Nginx as a reverse proxy. The website will be separated into public and private sections with authentication handled through OAuth2 or OpenID Connect. The frontend will be styled using Tailwind CSS.

# TODO
## Project
1. Set up Docker
2. Set up GitHub Actions for CI
3. Ensure Heroku deployment works (CD)
4. Set up a database (PostgreSQL)
5. Set up a cache (Redis)
6. Set up Nginx
7. Set up a message broker (RabbitMQ)
8. Set up Nginx

## Frontend
1. Add Tailwind CSS
2. Set up basic React app
3. Set up Auth guard and prepare for authentication

## Backend (Rust)
1. Set up REST API for communication with frontend (through RabbitMQ)
2. Set up authentication using OAuth2 (maybe OpenID Connect)
3. Set up database models and migrations
4. Set up caching for frequently accessed data
5. Set up logging and monitoring
6. Set up error handling and validation
7. Set up unit tests and integration tests
8. Set up API documentation (Swagger or similar)
9. Set up rate limiting and security measures