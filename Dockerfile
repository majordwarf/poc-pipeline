# Using official Python image from docker repository.
# Having version with alpine as base would reduce the
# image size significantly.
FROM python:3.9.2-alpine

# Create a directory for the flask application.
WORKDIR /server

#Expose flask application port to public.
EXPOSE 5000

# Copy the flask application inside the directory
# created in the previous step.
COPY /app /server

# Install the all dependencies using pip.
RUN pip install -r requirements.txt

# Set entry point for the user to manually change
# initilization of the docker image.
ENTRYPOINT [ "python" ]

# Default command to be executed on initilization
# if not overriden by the user.
CMD [ "-m", "flask", "run", "--host=0.0.0.0" ]
