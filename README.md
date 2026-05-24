# 🚀 Ekafy Server Engine

Ekafy Engine is a Linux-based server orchestration CLI system for deploying, managing, and scaling backend applications using a unified command-line interface.

It automates:

- Application lifecycle management  
- API Gateway provisioning  
- Web/Nginx configuration  
- PostgreSQL registry management  
- PM2 process orchestration  
- Multi-app deployment system  

---

## ⚙️ Features

- 🚀 Single CLI control: `ekafy`
- 📦 Automated server initialization
- 🧠 App registry system (PostgreSQL)
- 🌐 API Gateway (Express + Proxy)
- ⚡ PM2 process management
- 🔐 Secure system user isolation
- 🌍 Nginx reverse proxy auto-setup
- 📁 Modular architecture
- 🔄 Git-based update system (planned)

---

## 📦 Installation

### 1. Clone repository
```bash
git clone https://github.com/YOUR_ORG/ekafy-engine.git
cd ekafy-engine
2. Build Debian package (recommended)
dpkg-deb --build ekafy-deb
sudo dpkg -i ekafy-deb.deb
3. Initialize system
sudo ekafy init
🚀 Usage
Core Commands
ekafy init
ekafy registry
ekafy remove
📦 Product Management
ekafy product create
ekafy product list
ekafy product delete <app_name>
🧩 Application Lifecycle
ekafy app start <app>
ekafy app stop <app>
ekafy app restart <app>
ekafy app status <app>
ekafy app logs <app>
ekafy app deploy <app>
🌐 Web Management
ekafy web <app> install
ekafy web <app> reinstall
ekafy web <app> remove
ekafy web <app> validate
ekafy web <app> status
🏗️ System Architecture
/srv/core
│
├── ekafy-functions.sh
├── ekafy-init.sh
├── ekafy-remove.sh
├── web-functions.sh
├── modules/
│   ├── app.sh
│   ├── product.sh
│   ├── deploy.sh
│   ├── git.sh
│   └── registry.sh
│
├── core/
│   └── api-gateway (Express + Proxy)
│
├── apps/
├── logs/
├── config/
└── secrets/
🌐 API Gateway

Ekafy automatically generates a dynamic API Gateway:

Built with Express.js
Uses http-proxy-middleware
Dynamically loads apps from PostgreSQL registry
Runs under PM2
🗄️ Database

PostgreSQL registry contains:

Tables
apps → application registry
reserved_ports → port allocation system
🔄 Update System (Planned)
ekafy update

Features:

Pull latest from GitHub
Auto backup before update
Restart services
Rollback support (planned)
🧪 Example Workflow
sudo ekafy init
ekafy product create
ekafy app deploy myapp
ekafy web myapp install
🛠 Requirements
Ubuntu / Debian server
Node.js 18+
PostgreSQL
PM2
Nginx
Git
🔐 Security Model
Dedicated system user: ekafy
Restricted directory permissions
Root-only initialization
Isolated app execution via PM2
📌 Roadmap
CLI engine
API Gateway
Registry DB
PM2 integration
ekafy update system
Rollback system
Plugin system
Dashboard UI
Multi-server cluster mode
👨‍💻 Author

Ekafy Engine Development

📜 License

MIT License (or your custom license)
