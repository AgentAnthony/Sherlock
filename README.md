```
     _               _            _    
    | |             | |          | |   
 ___| |__   ___ _ __| | ___   ___| | __
/ __| '_ \ / _ \ '__| |/ _ \ / __| |/ /
\__ \ | | |  __/ |  | | (_) | (__|   < 
|___/_| |_|\___|_|  |_|\___/ \___|_|\_\
```

# Sherlock - Web Inspector
I wrote this script because over the years I have had to do various web application aseessments and one of the most time consuming part is performing the discovery, network vulnerability and web vulnerability scans. Though this does not do all that, however it takes care of the basics for me/you. 

## Install
```
cd /opt/
git pull https://github.com/gbiagomba/Sherlock
cd Sherlock
./install.sh
```

## Usage
```
./WebInspector
```
Do not worry all the prompts will be asked as the tool runs

## TODO
- [ ] Un-initialize variables
- [ ] Add multi-thread parallel processing
- [ ] Move all subroutines into functions
- [ ] Limit amount of data stored to disk, use more variables
- [x] Add SSL (e.g., sslyze, ssltest or testssl) checking later [done]
- [ ] Add zipping of all content and sending it via some medium (e.g., email, ftp, etc)
- [x] Write install script [done]
- [ ] Create Moriarty script
- [ ] Create Watson script 

## Future Plans
I plan on converting this into a python script later down the road...just an FYI

```
           ."""-.
          /      \
          |  _..--'-.
          >.`__.-"";"`
         / /(     ^\    (
         '-`)     =|-.   )
          /`--.'--'   \ .-.
        .'`-._ `.\    | J /
  jgs  /      `--.|   \__/
```