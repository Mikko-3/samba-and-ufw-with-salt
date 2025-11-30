palomuuri-ufw-enable:
  cmd.run:
    - name: ufw enable
    - unless: "ufw status | grep -q 'Status: active'"

palomuuri-135:
  cmd.run:
    - name: ufw allow 135/tcp
    - unless: "ufw status | grep -q '135/tcp'"

palomuuri-139:
  cmd.run:
    - name: ufw allow 139/tcp
    - unless: "ufw status | grep -q '139/tcp'"

palomuuri-445:
  cmd.run:
    - name: ufw allow 445/tcp
    - unless: "ufw status | grep -q '445/tcp'"
