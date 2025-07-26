# 📱 Ousia – A Privacy-First Social Media App

> 🧠 Powered by Sentiment Analysis · 🎓 Final Year Project · 🔒 Child Protection Focus

---

## 🌟 Overview

**Ousia** is a mobile-first social media platform designed to **foster safe digital communication**, especially for underage users. Leveraging **AI-powered sentiment analysis**, it automatically detects and blocks **hate speech**, **NSFW content**, and **toxicity** in real-time, ensuring a **positive online environment**.

This project was built as part of my **Final Year Project** to address the growing concern of children’s exposure to harmful content online.

---

## 🚀 Features

- ✨ Real-time sentiment analysis using ML models
- 🧼 Automatic filtering of hate/NSFW content
- 🔒 Parent notifications for inappropriate messages
- 🛑 Underage protection and content moderation
- 📷 Media upload support (images/videos)
- 🧾 Commenting, liking, and friend requests
- 🔍 Search and explore public posts
- ⚙️ Admin panel for content oversight
- 🐳 Dockerized backend for scalable deployment

---

## 🛠️ Tech Stack

| Layer         | Tech Used |
|---------------|-----------|
| **Frontend**  | Flutter   |
| **Backend**   | Django + Django REST Framework |
| **AI/ML**     | Still in development so not sure yet. |
| **Database**  | PostgreSQL |
| **Storage**   | Cloudinary |
| **Containerization** | Docker + docker-compose |
| **Auth**      | JWT with Argon2 hashing |
| **Docs**      | Swagger (drf-yasg) |

---

## 📦 Folder Structure

```bash
.
├── accounts/              # User authentication, JWT, password hashing
├── core/                  # Social features (posts, comments, friendships)
├── communication/         # Real time chat functionality using Django channels
├── myproject/             # Django project settings
├── Dockerfile             # Docker image definition
├── docker-compose.yml     # Dev environment setup
├── requirements.txt       # Python dependencies
└── manage.py              # Django entry point