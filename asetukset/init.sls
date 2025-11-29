palomuuri:
  cmd.run:
    - name: sudo ufw enable
    - name: sudo ufw allow salt
    - name: sudo ufw allow 135/tcp
    - name: sudo ufw allow 139/tcp
    - name: sudo ufw allow 445/tcp
