palomuuri-salt:
  cmd.run:
    - name: ufw allow salt
    - unless: "ufw status | grep -iq 'salt'"
    
