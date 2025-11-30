## Samban asennus paikallisesti Workstationille

Asennettuani saltin, asensin workstation koneelle samban ja smbclient ohjelmiston. Muokkasin /etc/samba/smb.conf tiedostoon asetukset.

```
[global]
        log file = /var/log/samba/%m
        log level = 1
        server role = standalone server

[NAS]
        # This share requires authentication to access
        path = /srv/samba/nas/
        read only = no
        inherit permissions = yes
        valid users = @nasUsers
```

Loin uuden käyttäjän ja lisäsin sen Samban tietokantaan seuraavilla komennoilla:

```
useradd -M -s /sbin/nologin demoUser
passwd demoUser
smbpasswd -a demoUser
```

Tämän jälkeen loin uuden ryhmän samalla nimellä kuin smb.conf tiedostossa:

```
groupadd nasUsers
usermod -aG nasUsers demoUser
```

Sitten hakemiston luominen ja sen oikeuksien asettaminen:

```
mkdir -p /srv/samba/nas/
chgrp -R demoGroup /srv/samba/nas/
chmod 2770 /srv/samba/nas/
```

Testasin konfiguraation “testparm -s” komennolla virheiden varalta, tulos oli toimiva konfiguraatio.
Lopuksi Samban käynnistäminen ja sen käynnistäminen bootissa:
`sudo systemctl enable smbd`
Nyt Samba on asennettu ja konfiguroitu. Testasin toimivuutta yhdistämällä jakoon:
`smbclient -U demoUser //workstation/nas`

<img width="940" height="124" alt="image" src="https://github.com/user-attachments/assets/7125ed7c-4e22-4108-9298-6fedd6cd10d1" />

Kaikki toimi oikein. Kokeilin myös yhdistää käyttäjällä, joka ei kuulu nasUsers ryhmään:

<img width="940" height="99" alt="image" src="https://github.com/user-attachments/assets/64b20fd8-0bb3-48a2-9b0e-6b3a422e9e6e" />

Käyttäjällä ei ole pääsyä hakemistoon, joten pääsynhallinta toimii oikein.

## Samba Saltilla

Ensin loin smb-conf hakemiston /srv/salt/ hakemistoon.
Loin hakemistoon init.sls tiedoston, sekä kopioin smb.conf tiedoston /etc/samba/ hakemistosta.
Smb.conf ei tarvinnut enää muokata, se sisältää tarvittavat asetukset.
Loin init.sls tiedostoon aluksi tilan, joka kopioi smb.conf tiedoston oikeaan paikkaan orjalla:

```
/etc/samba/smb.conf:
  file.managed:
    - source: salt://samba-conf/smb.conf
```

Tämän jälkeen testasin toiminnan paikallisesti ”sudo salt-call –local” komennon avulla.
Tiedostoon ei tarvinnut tehdä muutoksia, koska se oli jo oikeassa tilassa, joten tila toimi.
Seuraavaksi vuorossa oli käyttäjän ja käyttäjäryhmän luominen.

```
wsUser1:
  user.present:
    - createhome: false
    - shell: /usr/sbin/nologin
    - password: testi123

nasUsers:
  group.present:
    - addusers:
      - wsUser1
```

User.present luo uuden ”wsUser1” nimisen käyttäjän salasanalla ”testi123”, mutta ei luo käyttäjälle kotihakemistoa ”createhome: false” optiolla, sekä estää kirjautumisen shelliin asettamalla oletus shelliksi nologin.
Samba ei tarvitse näitä asioita toimiakseen, eikä käyttäjää ole tarkoitus käyttää muuhun paikallisella koneella, joten nämä eivät ole tarpeellisia.  
Group.present toimii samalla periaatteella kuin user.present, mutta ryhmille.
Se luo uuden ”nasUsers” ryhmän ja lisää ”wsUser1” tilin ryhmän jäseneksi.
Näin tilillä on oikeudet Samban jaettuun kansioon.
Testasin jälleen toiminnan paikallisesti, Salt loi käyttäjän onnistuneesti ja lisäsi sen ryhmään, jonka se loi onnistuneesti.

Jotta tiedostojen jako voi onnistua, tarvitaan jaettava hakemisto. Loin sen file.directory:n avulla:

```
/srv/samba/nas:
  file.directory:
    - makedirs: true
    - group: nasUsers
    - mode: 2770
    - recurse:
      - group
```

File.directory toimii samankaltaisesti kuin file.managed, mutta hakemistoille.
”Makedirs: true” optio luo koko hakemistopolun (/srv/samba/nas), ilman tätä Salt yrittäisi luoda vain nas hakemiston /srv/samba/ polkuun, mutta koska samba hakemistoa ei ole oletuksena srv hakemistossa, tila ei suoriutuisi onnistuneesti.
Group asettaa hakemiston ryhmän ja mode oikeudet hakemistoon ja tiedostoihin.
Recurse optio määrittää, että hakemistoon jo luodut tiedostot ja hakemistot perivät oikeudet määritellyltä ryhmältä.
Testauksessa Salt loi hakemiston onnistuneesti oikeilla oikeuksilla.

Ennen kuin Samban pääsynhallinta toimii, on luotu tili lisättävä Sambaan.
Tämä onnistuu smbpasswd komennolla, joten loin init.sls tiedostoon tilan, joka ajaa skriptin orjalla.

```
smbpasswd:
  cmd.script:
    - name: salt://samba-conf/smb-script.sh
    - onchanges:
      - wsUser1
```

Cmd.script lataa skriptitiedoston masterilta ja ajaa sen orjalla.
”Name” kertoo ladattavan tiedoston sijainnin ja ”onchanges” suorittaa skriptin vain, jos ”wsUser1” moduuli on suoritettu, eli käyttäjä on luotu tai sen asetuksia muokattu.
Näin skriptistä saadaan idempotentti.

Loin masterille skriptitiedoston samalla nimellä ja samaan polkuun kuin init.sls tiedostossa spesifioin. Skriptin sisältö:

```
user="wsUser1"
pass="testi123"

printf "$pass\n$pass\n" | smbpasswd -a -s $user
```

Skripti luo muuttujat user ja pass, joihin se tallettaa käyttäjänimen ja salasanan.
Tämän jälkeen skripti ajaa smbpasswd ohjelman, jossa -a lisää olemassa olevan käyttäjän ja -s kertoo smbpasswd suoritettavan ilman prompteja (silent).
Tämän option on tarkoitus helpottaa skriptaamista.
Normaalisti smbpasswd kysyy salasanan ja sen jälkeen salasana on toistettava, jotta se tallentuu.
Printf kirjoittaa salasanan ja rivinvaihdon, jotta smbpasswd suorittuu onnistuneesti.

Testauksessa ilmeni alun perin ongelma, jossa smbpasswd ei lisännyt käyttäjää.
Olin kirjoittanut skriptin ensin käyttäen echo -e komentoa printf sijaan, ja tämä ei jostain syystä halunnut toimia.
Vaihdettuani sen printf komentoon muuttamatta mitään muuta, skripti toimi.

Viimeisenä, on Samba käynnistettävä/käynnistettävä uudelleen.

```
smbd:
  service.running:
    - onchanges:
      - file: /etc/samba/smb.conf
```

”Onchanges” optio tarkkailee, onko smb.conf tila ajettu ja onko se tehnyt muutoksia, jolloin palvelu käynnistetään uudelleen vain jos muutoksia on tehty.
Näin tila on idempotentti. 
