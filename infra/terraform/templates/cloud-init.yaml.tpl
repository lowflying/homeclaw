#cloud-config

hostname: homeclaw-prod
manage_etc_hosts: true

users:
  - name: deploy
    groups: [docker]
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIALr/dzv2L+57dyNgv+nVxKuQa3yyMuA7AlQB3NRBa0w hetzner-homeclaw-deploy

package_update: true
package_upgrade: true

packages:
  - docker.io
  - docker-compose-plugin
  - ufw
  - fail2ban

runcmd:
  # Docker
  - systemctl enable --now docker

  # Mount point
  - mkdir -p /mnt/postgres-data

  # Wait for volume device to appear (up to 60s)
  - |
    DEVICE="/dev/disk/by-id/scsi-0HC_Volume_${volume_id}"
    elapsed=0
    until [ -e "$DEVICE" ] || [ $elapsed -ge 60 ]; do
      sleep 2
      elapsed=$((elapsed + 2))
    done
    if [ ! -e "$DEVICE" ]; then
      echo "ERROR: volume device $DEVICE did not appear after 60s" >&2
      exit 1
    fi

  # Mount if not already mounted
  - mountpoint -q /mnt/postgres-data || mount /dev/disk/by-id/scsi-0HC_Volume_${volume_id} /mnt/postgres-data

  # Persist mount in fstab
  - |
    FSTAB_ENTRY="/dev/disk/by-id/scsi-0HC_Volume_${volume_id}  /mnt/postgres-data  ext4  defaults,nofail  0  2"
    grep -qF "scsi-0HC_Volume_${volume_id}" /etc/fstab || echo "$FSTAB_ENTRY" >> /etc/fstab

  # Ownership
  - chown deploy:deploy /mnt/postgres-data

  # Harden SSH
  - sed -i 's/^#\?Port .*/Port 2222/' /etc/ssh/sshd_config
  - sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
  - systemctl restart ssh

  # Firewall (belt-and-suspenders on top of Hetzner firewall)
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow 2222/tcp
  - ufw --force enable

  # Fail2ban
  - systemctl enable fail2ban
  - systemctl start fail2ban
