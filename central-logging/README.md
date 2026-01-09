# Centralized Logging 

## Overview

This document explains how to activate the **Centralized Logging** infrastructure on the customer side. The setup can be performed either **by the customer** or **by our team**, depending on the agreement.

The centralized logging architecture allows logs from customer environments to be securely collected and monitored in a multi-tenant setup.

## Supported Environments

- Standalone instances (VM / Bare Metal / Cloud VM)
- Kubernetes environments

---

## 1. Instance-Based Installation

For standalone instances, the centralized logging agent is installed via a shell script.

### Prerequisites

- Root or sudo access
- Outbound network access to the Central Logging endpoint

### Installation Steps

**Step 1:** Download or copy the installation script to the instance:

```bash
curl -O https://example.com/install-central-logging.sh
chmod +x install-central-logging.sh
```

**Step 2:** Execute the script:

```bash
sudo ./install-central-logging.sh
```

**Step 3:** During execution, you will be prompted to enter:

- **Tenant Email**
- **Username**
- **Password**

These credentials will be used to configure secure log forwarding.

---

## 2. Kubernetes Environment

For Kubernetes clusters, Fluent Bit is deployed using Helm.

### Prerequisites

- Helm v4 installed
- Cluster-admin or sufficient RBAC permissions

### Installation Steps

Run the following Helm command:

```bash
helm upgrade --install fluent-bit fluent/fluent-bit \
  -f values_central-logging.yaml \
  --set TENANT_EMAIL="your@email.address" \
  --set USERNAME="username" \
  --set PASSWORD="password"
```

**Parameters:**

| Parameter | Description |
|-----------|-------------|
| `TENANT_EMAIL` | Your organization's email address |
| `USERNAME` | Centralized logging username |
| `PASSWORD` | Centralized logging password |

---

