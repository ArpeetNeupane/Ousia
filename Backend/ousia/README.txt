📱 Ousia – A Child-Friendly Social Media App

🎓 Final Year Project · 🔒 Child Protection Focus


---

🌟 Overview

Ousia is a mobile-first social media platform designed to foster safe digital communication, especially for underage users. Leveraging OCR technology, age detection and facial similarity match it blocks potential overage users (over the age of 13 and under 7), AI-powered nsfw analysis, it automatically detects and blocks NSFW content, and toxicity in real-time, ensuring a positive online environment.

This project was built as part of my Final Year Project to address the growing concern of children’s exposure to harmful content online.

---


🚀 Features

- 🧼 Automatic filtering of hate/NSFW content (text, images and video)
- 🔒 Parent notifications for inappropriate messages
- 🛑 Underage protection and content moderation
- 📷 Media upload support (images/videos)
- 🧾 Liking posts and friend requests
- 🔍 Search and explore public posts
- ⚙️ Admin panel for content oversight
- 🐳 Dockerized backend for scalable deployment

---


🛠️ Tech Stack

| Layer              | Tech Used                             |
|--------------------|---------------------------------------|
| Frontend           | Flutter                               |
| Backend            | Django + Django REST Framework        |
| AI/ML              | Hugging Face                          |
| Database           | PostgreSQL                            |
| Media Storage      | Cloudinary                            |
| Containerization   | Docker + docker-compose               |
| Auth               | JWT with Argon2 hashing               |
| Docs               | Swagger (drf-yasg)                    |

---


📦 Folder Structure (Backend)

├── accounts/              # User authentication, JWT, password hashing
├── core/                  # Social features (posts, comments, friendships)
├── communication/         # Real time chat functionality using Django channels
├── myproject/             # Django project settings
├── Dockerfile             # Docker image definition
├── docker-compose.yml     # Dev environment setup
├── requirements.txt       # Python dependencies
└── manage.py              # Django entry point
