# INSTALLATION INSTRUCTIONS FOR RASPBERRY PI 3 WITH TRIXIE ARM64

## Prerequisites
Before you begin, ensure that you have the following:
- A Raspberry Pi 3 with Trixie ARM64 installed.
- An internet connection.
- Basic knowledge of using the terminal.

## Installation Steps

### Step 1: Clone the Repository
Open a terminal and clone the project repository from GitHub:
```bash
git clone https://github.com/yourusername/rpi3-trixie-installer.git
cd rpi3-trixie-installer
```

### Step 2: Run the Installation Script
The main installation script will handle the setup of all necessary components. Run the following command:
```bash
sudo bash scripts/install.sh
```
This script will:
- Install Node-RED and its dependencies.
- Install and configure PostgreSQL.
- Set up Python and its dependencies.
- Verify the installation of all services.

### Step 3: Configure Node-RED
After the installation is complete, you can access Node-RED by navigating to:
```
http://localhost:1880
```
You may need to import the flows from `nodered/flows.json` to set up your Node-RED environment.

### Step 4: Verify Installation
To ensure that all services are running correctly, execute the verification script:
```bash
bash scripts/verify-installation.sh
```
This script will check the status of Node-RED, PostgreSQL, and other services.

## Additional Configuration
- **Environment Variables**: Copy `config/env.example` to `.env` and modify it according to your environment settings.
- **PostgreSQL Configuration**: Adjust the settings in `config/postgresql.conf` as needed for your database setup.

## Troubleshooting
If you encounter issues during installation or setup, refer to the `docs/TROUBLESHOOTING.md` file for common problems and solutions.

## Conclusion
You have successfully installed and configured the project on your Raspberry Pi 3. For further usage instructions, please refer to `TUTORIEL_COMPLET.md`.