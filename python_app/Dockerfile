FROM python:3.7

RUN mkdir /app
WORKDIR /app
ADD . /app/
RUN pip install -r /app/requirements.txt

ENV GOOGLE_APPLICATION_CREDENTIALS="/app/consummate-tine-325216-79c2638584bd.json"
CMD ["python", "/app/main.py"]
