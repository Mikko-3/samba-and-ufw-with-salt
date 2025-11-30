# Projektin raportti

Tässä raportissa kerrotaan projektin toteutuksen vaiheista.
Projektin tehtävänanto löytyy kurssin sivulta kohdasta h6 - miniprojekti (Karvinen 2025).

## Ympäristö

**Mikko:**  
Host - Lenovo ThinkPad L14  
OS: Windows 11 25H2  
CPU: AMD Ryzen 5 Pro 4650U  
RAM: 16 GB DDR4  
SSD: 256 GB NVMe

Virtualisointiohjelma: Oracle VirtualBox  
Virtuaalikoneiden OS: Debian 13 Trixie  
CPU & RAM: 2 cores, 4GB  
Virtuaalikoneiden nimet: workstation (master) ja sambaServer (slave)  
Virtuaalinen NAT verkko "Projekti": 10.0.2.0/24  
IP osoitteet: workstation - 10.0.2.4 , sambaServer - 10.0.2.15

**Niilo:**

Fyysinen kone
- MacBook Air M3

Virtuaali kone
- UTM
- Debian 12 (bookworm)
  - Muisti 4 GB
  - Tila 80 GB

## Suunnittelu

- Mikon ideasta lähdimme toteuttamaan Samba tiedostopalvelimen käyttöä. Mikko sai osakseen Samban ja Niilo osansa Saltista ja UFW:n asetukset.

## Samban asennus paikallisesti Workstationille

Asennettuani Saltin, asensin workstation koneelle Samban ja smbclient ohjelmiston. Muokkasin /etc/samba/smb.conf tiedostoon asetukset.

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

(SambaWiki, 2025.)

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

(SambaWiki, 2025.)

Testasin konfiguraation `testparm -s` komennolla virheiden varalta, tulos oli toimiva konfiguraatio.
Lopuksi Samban käynnistäminen ja sen käynnistäminen bootissa:
`sudo systemctl enable smbd`.
Nyt Samba on asennettu ja konfiguroitu. Testasin toimivuutta yhdistämällä jakoon:
`smbclient -U demoUser //workstation/nas`.

<img width="470" height="62" alt="image" src="https://github.com/user-attachments/assets/7125ed7c-4e22-4108-9298-6fedd6cd10d1" />

Kaikki toimi oikein. Kokeilin myös yhdistää käyttäjällä, joka ei kuulu nasUsers ryhmään:

<img width="470" height="50" alt="image" src="https://github.com/user-attachments/assets/64b20fd8-0bb3-48a2-9b0e-6b3a422e9e6e" />

Käyttäjällä ei ole pääsyä hakemistoon, joten pääsynhallinta toimii oikein.

## Samba Saltilla

Seuraavaksi oli toteuttettava sama Saltin avulla.

Ensin loin smb-conf hakemiston /srv/salt/ hakemistoon workstation koneelle.
Loin hakemistoon init.sls tiedoston, sekä kopioin smb.conf tiedoston /etc/samba/ hakemistosta.
Smb.conf ei tarvinnut enää muokata, se sisälsi jo tarvittavat asetukset.
Loin init.sls tiedostoon aluksi tilan, joka kopioi smb.conf tiedoston oikeaan paikkaan orjalla:

```
/etc/samba/smb.conf:
  file.managed:
    - source: salt://samba-conf/smb.conf
```

Tämän jälkeen testasin toiminnan paikallisesti `sudo salt-call --local` komennon avulla.
Tiedostoon ei tarvinnut tehdä muutoksia, koska se oli jo oikeassa tilassa, joten tila toimi oikein.

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

`User.present` luo uuden ”wsUser1” nimisen käyttäjän salasanalla ”testi123”, mutta ei luo käyttäjälle kotihakemistoa ”createhome: false” optiolla, sekä asettaa oletus shellin optiolla "shell" (VMware a. 2025).
Asettamalla "shell" optioon "nologin", estetään käyttäjän kirjautuminen shelliin (Stackexchange 2016).
Samba ei tarvitse näitä asioita toimiakseen, eikä käyttäjää ole tarkoitus käyttää muuhun paikallisella koneella, joten nämä eivät ole tarpeellisia (SambaWiki 2025).  
`Group.present` luo uuden ”nasUsers” ryhmän ja lisää ”wsUser1” tilin ryhmän jäseneksi (VMware b. 2025).
Näin tilillä on oikeudet Samban jaettuun kansioon.
Testasin jälleen toiminnan paikallisesti, Salt loi käyttäjän onnistuneesti ja lisäsi sen ryhmään, jonka se loi onnistuneesti.

Jotta tiedostojen jako voi onnistua, tarvitaan jaettava hakemisto. Loin sen `file.directory`:n avulla:

```
/srv/samba/nas:
  file.directory:
    - makedirs: true
    - group: nasUsers
    - mode: 2770
    - recurse:
      - group
```

`File.directory` toimii samankaltaisesti kuin `file.managed`, mutta hakemistoille.
”Makedirs: true” optio luo koko hakemistopolun (/srv/samba/nas), ilman tätä Salt yrittäisi luoda vain nas hakemiston /srv/samba/ polkuun, mutta koska samba hakemistoa ei ole oletuksena srv hakemistossa, tila ei suoriutuisi onnistuneesti.
"Group" asettaa hakemiston ryhmän ja "mode" oikeudet hakemistoon ja tiedostoihin.
"Recurse" optio määrittää, että hakemistoon jo luodut tiedostot ja hakemistot perivät oikeudet määritellyltä ryhmältä. (VMware b. 2025.)
Testauksessa Salt loi hakemiston onnistuneesti oikeilla oikeuksilla.

Ennen kuin Samban pääsynhallinta toimii, on luotu tili lisättävä Sambaan.
Tämä onnistuu `smbpasswd` komennolla (SambaWiki 2025), joten loin init.sls tiedostoon tilan, joka ajaa skriptin orjalla.

```
smbpasswd:
  cmd.script:
    - name: salt://samba-conf/smb-script.sh
    - onchanges:
      - wsUser1
```

`Cmd.script` lataa skriptitiedoston masterilta ja ajaa sen orjalla.
”Name” optio kertoo ladattavan tiedoston sijainnin. (VMware d. 2025.)
Optio ”onchanges” suorittaa skriptin vain, jos ”wsUser1” moduuli on suoritettu, eli käyttäjä on luotu tai sen asetuksia muokattu (VMware e. 2025).
Näin skriptistä saadaan idempotentti.

Loin masterille skriptitiedoston samalla nimellä ja samaan polkuun kuin init.sls tiedostossa spesifioin. Skriptin sisältö:

```
user="wsUser1"
pass="testi123"

printf "$pass\n$pass\n" | smbpasswd -a -s $user
```

Skripti luo muuttujat user ja pass, joihin se tallettaa käyttäjänimen ja salasanan.
Tämän jälkeen skripti ajaa smbpasswd ohjelman, jossa -a lisää olemassa olevan käyttäjän ja -s kertoo smbpasswd suoritettavan ilman prompteja (Samba s.a.).
Tämän option on tarkoitus helpottaa skriptaamista.  
Normaalisti smbpasswd kysyy salasanan ja sen jälkeen salasana on toistettava, jotta se tallentuu.
Printf kirjoittaa salasanan ja rivinvaihdon, jotta smbpasswd suorittuu onnistuneesti.

Testauksessa ilmeni alun perin ongelma, jossa smbpasswd ei lisännyt käyttäjää.
Olin kirjoittanut skriptin ensin käyttäen `echo -e` komentoa printf sijaan, ja tämä ei jostain syystä halunnut toimia (Stackexchange 2022).
Vaihdettuani sen printf komentoon muuttamatta mitään muuta, skripti toimi.

Viimeisenä, on Samba käynnistettävä/käynnistettävä uudelleen.

```
smbd:
  service.running:
    - onchanges:
      - file: /etc/samba/smb.conf
```

”Onchanges” optio tarkkailee, onko "/etc/samba/smb.conf" tila ajettu onnistuneesti ja onko se tehnyt muutoksia, jolloin palvelu käynnistetään uudelleen vain jos muutoksia on tehty (VMware e. 2025). 
Näin tila on idempotentti. 

## Saltin ja UFW:n konfigurointi

- Ensin tein asennus kansion, jossa init.sls -tiedosto hoitaa tarvittavan Samban ja UFW:n asennukset:

  <img width="167" height="105" alt="Screenshot 2025-11-30 at 18 45 08" src="https://github.com/user-attachments/assets/f00370c9-503c-4417-a880-a67bb372f18a" />

- Välissä tein top.sls tiedoston, kun luulin olevani helpoilla palomuurin asetusten kanssa.

  <img width="155" height="108" alt="Screenshot 2025-11-30 at 18 48 21" src="https://github.com/user-attachments/assets/29c31c12-6578-4a4e-9488-01ca53b4021e" />

- Palomuurin asetusten kanssa oli suurin vääntö, koska en tiennyt kuinka idempotenssi saataisiin toteutettua. Olin laittanut jokaisen portinmuunnoksen samaan cmd.run -komentolinjaan, jolloin ne ajettiin jokainen... joka kerta.

  <img width="526" height="370" alt="Screenshot 2025-11-29 at 15 46 12" src="https://github.com/user-attachments/assets/54c1df46-33ab-48cf-9ee6-b6df8d6e4023" />

  <img width="231" height="103" alt="Screenshot 2025-11-29 at 15 46 24" src="https://github.com/user-attachments/assets/b1a043c0-4af3-447a-9d0d-d58f3b461f3f" />

Lopulta laitoin kaikki komennot seuraavan kaltaiseen muotoon:

  <img width="415" height="84" alt="Screenshot 2025-11-30 at 18 34 20" src="https://github.com/user-attachments/assets/9b1003d2-7431-4958-ab2c-b448d476e7aa" />

Ja kaikki toimi.

- Rakentaminen oli minulle todella vaikeaa. Yritin monituisesti saada toista konetta luotua kloonaten ja yksilöiden asetuksia, mutta turhaan; en saanut klooni koneita alkuasetuksia pidemmälle,
  koska alkuperäisessä "koneessa" oli jotain korruptoitunut tai kloonaus korruptoi kloonit. Latasin sitten moneen vaiheen jälkeen uuden "kuvan" ja sain sen onneksi ylös ja testikuntoon. Ja parahiksi näin,
  sillä init.sls -tiedostot olivat toiminnassa.
  
  <img width="254" height="148" alt="Screenshot 2025-11-30 at 18 30 04" src="https://github.com/user-attachments/assets/0b146323-a5a5-43db-be4f-56fcf7ef4889" />

- Koska kaikki testimme eri koneilla eivät tuottaneet puhdasta tulosta, aloimme vielä tutkia mahdollisuutta saada top-fileen eri komentoja minioneille ja mastereille. Sellaista ratkaisua emme saaneet tässä ajassa kekattua, joten vain poistimme UFW:n konfigurointi osuudesta Saltin sallimisen: se aiheutti virheilmoituksia minion koneilla, mutta ei sellaisilla koneilla, joissa oli myös master.

## Testaus

Lopputulos testattiin kahdella tyhjällä virtuaalikoneella, workstation ja sambaServer.
Salt asennettiin molempiin koneisiin, workstationiin master ja sambaServeriin minion.
Lisäksi workstation koneeseen asennettiin smbclient ohjelma jakoon yhdistämistä varten ja git.
Tämän jälkeen projekti kloonattiin workstationille git avulla, luotiin `/srv/salt/` hakemisto ja kopioitiin projektin tiedostot readme.md, licence ja raportti.md lukuun ottamatta.

<img width="440" height="46" alt="image" src="https://github.com/user-attachments/assets/d114f3b2-b362-4666-bb07-6405b8fd2cd8" />

Tämän jälkeen ajettiin komento `sudo salt '*' state.apply`.

<img width="520" height="185" alt="image" src="https://github.com/user-attachments/assets/12e3e37f-6a1b-4c91-8d92-a942a0635c58" />

Kaikki tilat ajettiin onnistuneesti.

Seuraavaksi testattiin, toimiiko Samba jako smbclient ohjelmalla.

<img width="728" height="96" alt="image" src="https://github.com/user-attachments/assets/36a85a4f-2c43-4663-81b4-0ab6ae9c0a0d" />

Workstation saa yhteyden Samba jakoon.
Suljin smb yhteyden, tein uuden tekstitiedoston workstationilla ja kopioin sen sambaServerille.

<img width="864" height="313" alt="image" src="https://github.com/user-attachments/assets/72e43095-61fd-4828-a0d9-a2fd1b30fbd3" />

Seuraavaksi tarkastin tiedoston olemassaolon sambaServerillä.

<img width="681" height="45" alt="image" src="https://github.com/user-attachments/assets/06621682-2d58-4600-81dc-37f9425d19ad" />

Tiedostojen siirto palvelimelle toimii.  
Lopuksi ajoin `sudo salt '*' state.apply` uudelleen, tarkastaakseni idempotenssin.

<img width="517" height="181" alt="image" src="https://github.com/user-attachments/assets/17190911-4054-4d6a-8fab-da8d08dedd5d" />

Tila suoritettiin onnistuneesti, mutta yhtään muutosta ei tehty, sillä kaikki oli halutussa tilassa.

# Lähdeluettelo

- UFW [help.ubuntu.com](https://help.ubuntu.com/community/UFW)  
- UFW & Samba [askubuntu.com](https://askubuntu.com/questions/36608/ufw-firewall-still-blocking-smb-despite-adding-rules)  
- Salt project [SALT.STATES.CMD](https://docs.saltproject.io/en/latest/ref/states/all/salt.states.cmd.html#salt.states.cmd.run)  
- Tero Karvinen, https://terokarvinen.com/2021/install-debian-on-virtualbox/  https://terokarvinen.com/install-salt-on-debian-13-trixie/   https://terokarvinen.com/2018/03/28/salt-quickstart-salt-stack-master-and-slave-on-ubuntu-linux/

Karvinen, T. 2025. Palvelinten hallinta. Luettavissa: https://terokarvinen.com/palvelinten-hallinta/#h6-miniprojekti. Luettu: 30.11.2025.  
Samba. s.a. smbpasswd (8). Luettavissa: https://www.samba.org/samba/docs/current/man-html/smbpasswd.8.html. Luettu: 30.11.2025.  
SambaWiki. 2025. Setting up Samba as a Standalone Server. Luettavissa: https://wiki.samba.org/index.php/Setting_up_Samba_as_a_Standalone_Server. Luettu: 30.11.2025.  
Stackexchange. 2022. Shell script to set password for samba user. Luettavissa: https://unix.stackexchange.com/a/584414. Luettu: 30.11.2025.  
Stackexchange. 2016. What's the difference between /sbin/nologin and /bin/false. Luettavissa: https://unix.stackexchange.com/a/10867. Luettu: 30.11.2025.  
Stackoverflow. 2010. echo smbpasswd by --stdin doesn't work. Luettavissa: https://stackoverflow.com/a/3323978. Luettu: 30.11.2025.  
VMware a. 2025. salt.states.user. Luettavissa: https://docs.saltproject.io/en/latest/ref/states/all/salt.states.user.html. Luettu: 30.11.2025.  
VMware b. 2025. salt.states.group. Luettavissa: https://docs.saltproject.io/en/latest/ref/states/all/salt.states.group.html. Luettu: 30.11.2025.  
VMware c. 2025. salt.states.file. Luettavissa: https://docs.saltproject.io/en/latest/ref/states/all/salt.states.file.html#salt.states.file.directory. Luettu: 30.11.2025.  
VMware d. 2025. salt.states.cmd. Luettavissa: https://docs.saltproject.io/en/latest/ref/states/all/salt.states.cmd.html. Luettu: 30.11.2025.  
VMware e. 2025. Requisites and Other Global State Arguments. Luettavissa: https://docs.saltproject.io/en/latest/ref/states/requisites.html#requisites-onchanges. Luettu: 30.11.2025.
