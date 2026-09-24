# Ansible Automation

## Files

- `playbook.yml` — final playbook for Jenkins and SonarQube configuration.
- `requirements.yml` — required Ansible collections.
- `inventory.ini.example` — template only; Jenkins generates the real inventory from Terraform outputs.
- `inventory.ini` — generated at runtime and ignored by Git.

## Connection model

Jenkins is the Ansible controller. Targets are reached with AWS Systems Manager (SSM), so no SSH private key is required.

## Manual test on Jenkins

```bash
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```
