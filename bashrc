export M2_HOME=/home/erik/uportal/maven
export M2=$M2_HOME/bin
export PATH=$M2:$PATH

export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/
export PATH=$JAVA_HOME/bin:$PATH

export ANT_HOME=/home/erik/uportal/ant
export PATH=$PATH:$ANT_HOME/bin

export TOMCAT_HOME=/home/erik/uportal/tomcat
export PATH=$PATH:$TOMCAT_HOME
export JAVA_OPTS="-server -XX:MaxPermSize=512m -Xms1024m -Xmx2048m"

export GROOVY_HOME=/home/erik/uportal/groovy
export PATH=$PATH:$GROOVY_HOME/bin

export HSQLDB_HOME='/home/erik/uportal/hsqldb'
export PATH=$PATH:$HSQLDB_HOME/bin

colour=0x$(xxd -p -l 1 /dev/urandom)      # Random number from 0x00 to 0xff
(( colour=colour ))                       # Convert to decimal
export PS1='\[\e[38;5;'$colour'm\]\w $ '  # Set the foreground colour
