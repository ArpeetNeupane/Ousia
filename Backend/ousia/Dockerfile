#syntax=docker/dockerfile:1

FROM python:3.12.3-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y libmagic1

RUN pip install uv

COPY requirements.txt .
RUN uv pip install -r requirements.txt --system

COPY . .

EXPOSE 8000
CMD ["sh", "-c", "python", "manage.py", "runserver", "0.0.0.0:8000", "--noreload"]