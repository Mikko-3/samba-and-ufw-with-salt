base:
  '*':
    - asennus
    - asetukset
    - samba-conf

  'G@id:{{ grains.master }}':
    - pomo
    
