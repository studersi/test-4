##Tutorial 7 - Including OWASP ModSecurity Core Rules

###What are we doing?

We are embedding the OWASP ModSecurity Core Rule Set in our Apache web server and eliminating false alarms.

###Why are we doing this?

The ModSecurity Web Application Firewall, as we set up in Tutorial 6, still has barely any rules. But protection only works when you configure an additional rule set that is as comprehensive as possible and when you have eliminated all of the false alarms. The core rules provide generic blacklisting. This means that they inspect requests and responses for signs of attacks. The signs are often keywords or typical patterns that may be suggestive of a wide variety of attacks. This also entails false alarms being triggered.

###Requirements

* An Apache web server, ideally one created using the file structure shown in [Tutorial 1 (Compiling an Apache web server)](https://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/).
* Understanding of the minimal configuration in [Tutorial 2 (Configuring a minimal Apache server)](https://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/).
* An Apache web server with SSL/TLS support as in [Tutorial 4 (Configuring an SSL server)](https://www.netnea.com/cms/apache-tutorial-4-ssl-server-konfigurieren)
* An Apache web server with extended access log as in [Tutorial 5 (Extending and analyzing the access log)](https://www.netnea.com/cms/apache-tutorial-5-zugriffslog-ausbauen/)
* An Apache web server with ModSecurity as in [Tutorial 6 (Embedding ModSecurity)](https://www.netnea.com/cms/apache-tutorial-6-modsecurity-einbinden/)

We will be working with the new major release of the Core Rules, CRS3; short for Core Rule Set 3.0. The official distribution comes with an _INSTALL_ file that does a good job explaining the setup (after all, your's truly wrote a good deal of that file), but we will tweak the process a bit to suit our neats.

###Step 1: Downloading OWASP ModSecurity Core Rules

The ModSecurity Core Rules are being developed under the umbrella of *OWASP*, the Open Web Application Security Project. The rules themselves are available at *GitHub* and can be downloaded as follows.

```
$> cd /apache/conf
$> wget https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v3.0.0-rc2.tar.gz
$> tar xvzf v3.0.0-rc2.tar.gz
owasp-modsecurity-crs-3.0.0-rc2/
owasp-modsecurity-crs-3.0.0-rc2/CHANGES
owasp-modsecurity-crs-3.0.0-rc2/IDNUMBERING
owasp-modsecurity-crs-3.0.0-rc2/INSTALL
owasp-modsecurity-crs-3.0.0-rc2/KNOWN_BUGS
owasp-modsecurity-crs-3.0.0-rc2/LICENSE
owasp-modsecurity-crs-3.0.0-rc2/README.md
owasp-modsecurity-crs-3.0.0-rc2/crs-setup.conf.example
owasp-modsecurity-crs-3.0.0-rc2/documentation/
owasp-modsecurity-crs-3.0.0-rc2/documentation/OWASP-CRS-Documentation/
owasp-modsecurity-crs-3.0.0-rc2/documentation/README
...
$> sudo ln -s owasp-modsecurity-crs-3.0.0-rc2 /apache/conf/crs
$> cp crs/crs-setup.conf.example crs/crs-setup.conf
$> rm v3.0.0-rc2.tar.gz
```

This unpacks the base part of the core rules in the directory `/apache/conf/owasp-modsecurity-crs-3.0.0-rc2`. We create a link from `/apache/conf/crs` to this folder. Then we copy a file named `crs-setup.conf.example` to a new file `crs-setup.conf` and finally, we delete core rules tar file. The setup file allows us to tweak with many different settings. It is worth a look - if only to see what is all included. However, we are okay with the default settings and do not touch the file: We just make sure it is available under the new filename `crs-setup.conf`. Then we can continue to update the configuration to include the rules files.


###Step 2: Embedding Core Rules

In Tutorial 6, in which we embedded ModSecurity itself, we marked out a section for the core rules. We now add the Include directive in this section. Specifically, four parts are added to the existing configuration. (1) The core rules base configuration, (2) a part for self-defined ignore rules before the core rules. Then (3) the core rules themselves and finally a part (4) for self-defined ignore rules after the core rules.

The ignore rules are rules used for managing the false alarms described above. Some false alarms must be prevented before the corresponding core rule is loaded. Some false alarms can only be intercepted following the definition of the core rule itself. But one thing at a time. Here is the new block of configuration which we will insert into the base configuration, we assembled when we enabled ModSecurity.

```bash
# === ModSec Core Rules Base Configuration (ids: 900000-900999)

Include    /apache/conf/crs/crs-setup.conf

SecAction "id:900110,phase:1,pass,nolog,\
  setvar:tx.inbound_anomaly_score_threshold=1000,\
  setvar:tx.outbound_anomaly_score_threshold=1000"

SecAction "id:900000,phase:1,pass,nolog,\
  setvar:tx.paranoia_level=1"


# === ModSec Core Rules: Runtime Exclusion Rules
#                        order by id of ignored rule (ids: 10000-49999)

# ...


# === ModSecurity Core Rules Inclusion

Include    /apache/conf/crs/rules/*.conf


# === ModSec Core Rules: Config Time Exclusion Rules (no ids)

# ...

```

The Core Rules come with a base configuration file named `crs-setup.conf` which we prepared above. The copy step of the original example file guarantees that we can update the Core Rules distribution without harming our copy of the config file unless we want to. We now have the option to edit settings in that settings file. However, the strategy for this series of config files has been to define all the important things in our single apache configuration file. We do not want to insert the contents of the `crs-setup.conf` file into our configuration, but we include it, in order to get the minimal set of config items needed to run the Core Rules. I do not want to dive into all the options in the settings file, but it is worth to have a look.

As for now, we leave the file untouched, but we take three important values out of `crs-setup.conf` and define it in our config so we have them in sight at all times. We define two thresholds in the unconditional rule _900110_: The inbound anomaly score and the outbound anomaly score. This is done via the `setvar` action which sets both values to 1000. What does that mean? The Core Rules work with a scoring system. For every rule a request violates, there is a score being raised. When all the request rules have passed, the score is compared to the limit. If if hits the limit, the request is blocked. The same thing happens with the responses. 

The Core Rules come in blocking mode by default. If a rule is violated and the score hits the limit, the blocking will be effective immediately. But we are not yet sure our service runs smoothly and the danger of false alarms is always there. We want to avoid unwanted blocks, so we set the threshold at a value of 1000. Rule violations score with 5 points at most, so even if cumulation is possible, a request is unlikely to hit the limit. Yet, we remain in blocking mode and when we grow more confident in our configuration, we can lower the threshold gradually.

The second rule, id `900000`, defines the _Paranoia Level_. The groups are divided in four groups, paranoia level 1 - 4. As the name suggests, the higher the paranoia level, the more paranoid the rules. The default is paranoia level 1 where the rules are quite sane and false alarms are rare. When you raise the PL to 2, additional rules are enabled. Starting PL 2, you will face false alarms; also named false positives. This number grows with PL3 and when you arrive PL4 you are likely to face false alarms like mad; paranoid so to say. We will deal with false positives later in this tutorial, but for the moment you just need to be aware that you can control the aggressiveness of the ruleset with the paranoia level setting.

In the center of the config snipped follows the include statement, which loads all files with suffix `.conf` from the rules sub folder in the CRS directory. This is where all the rules are being loaded. Let's cast a eye on them:

```bash
$> ls -1
crs/rules/REQUEST-901-INITIALIZATION.conf
crs/rules/REQUEST-903.9001-DRUPAL-EXCLUSION-RULES.conf
crs/rules/REQUEST-903.9002-WORDPRESS-EXCLUSION-RULES.conf
crs/rules/REQUEST-905-COMMON-EXCEPTIONS.conf
crs/rules/REQUEST-910-IP-REPUTATION.conf
crs/rules/REQUEST-911-METHOD-ENFORCEMENT.conf
crs/rules/REQUEST-912-DOS-PROTECTION.conf
crs/rules/REQUEST-913-SCANNER-DETECTION.conf
crs/rules/REQUEST-920-PROTOCOL-ENFORCEMENT.conf
crs/rules/REQUEST-921-PROTOCOL-ATTACK.conf
crs/rules/REQUEST-930-APPLICATION-ATTACK-LFI.conf
crs/rules/REQUEST-931-APPLICATION-ATTACK-RFI.conf
crs/rules/REQUEST-932-APPLICATION-ATTACK-RCE.conf
crs/rules/REQUEST-933-APPLICATION-ATTACK-PHP.conf
crs/rules/REQUEST-941-APPLICATION-ATTACK-XSS.conf
crs/rules/REQUEST-942-APPLICATION-ATTACK-SQLI.conf
crs/rules/REQUEST-943-APPLICATION-ATTACK-SESSION-FIXATION.conf
crs/rules/REQUEST-949-BLOCKING-EVALUATION.conf
crs/rules/RESPONSE-950-DATA-LEAKAGES.conf
crs/rules/RESPONSE-951-DATA-LEAKAGES-SQL.conf
crs/rules/RESPONSE-952-DATA-LEAKAGES-JAVA.conf
crs/rules/RESPONSE-953-DATA-LEAKAGES-PHP.conf
crs/rules/RESPONSE-954-DATA-LEAKAGES-IIS.conf
crs/rules/RESPONSE-959-BLOCKING-EVALUATION.conf
crs/rules/RESPONSE-980-CORRELATION.conf
```

The rule files are grouped in request and in response rules. We start off with an initialization rule file. There are a lot of things commented out in the `crs-setup.conf` file. These values are simply set to their default value in the 901 rule file. Then follows two application specific rule files for Wordpress and Drupal; followed by an exceptions file that is mostly irrelevant to us. Starting with 910, we have the real rules. Every file is dedicated to a topic or type of attack. The core rules occupy the ID namespace from 900.000 to 999.999. The first three digits correspond with the three digit prefix in the rule id. This means the IP reputation rules in `REQUEST-910-IP-REPUTATION.conf` will occupy the rule range 910.000 - 910.999. The method enforcement follows between 911.000 - 911.999, etc.. Some of these rule files are small and they do not use up their assigned rule range by far. Others are much bigger and the infamous SQL Injection rules run the risk of touching their ID roof one day.

An important rule file is `REQUEST-949-BLOCKING-EVALUATION.conf`. This is where the anomaly score is checked against the inbound threshold and the request is being blocked accordingly.


Then start the outbound rules, which are less numerous and basically check for code and error leakages. The outbound score is checked in the file with the 980 prefix.

Some of the rules come with data files. These files with a `.data` ending reside in the same folder with the rule files. Data files are typically used when the request has to be checked against a long list of keywords, like unwanted user agents or php function names. Have a look if you are interested.

Before and after the rules include, there is a bit of config space reserved. This is where we will be handling false alarms in the future. Some of them are being treated before the rules are loaded in the configuration; some after the loading. We'll return to this further later in this tutorial.

Here is the complete apache configuration including ModSecurity and the core rules:

```bash
ServerName        localhost
ServerAdmin       root@localhost
ServerRoot        /apache
User              www-data
Group             www-data
PidFile           logs/httpd.pid

ServerTokens      Prod
UseCanonicalName  On
TraceEnable       Off

Timeout           10
MaxClients        100

Listen            127.0.0.1:80
Listen            127.0.0.1:443

LoadModule        mpm_event_module        modules/mod_mpm_event.so
LoadModule        unixd_module            modules/mod_unixd.so

LoadModule        log_config_module       modules/mod_log_config.so
LoadModule        logio_module            modules/mod_logio.so

LoadModule        authn_core_module       modules/mod_authn_core.so
LoadModule        authz_core_module       modules/mod_authz_core.so

LoadModule        ssl_module              modules/mod_ssl.so

LoadModule        unique_id_module        modules/mod_unique_id.so
LoadModule        security2_module        modules/mod_security2.so

ErrorLogFormat          "[%{cu}t] [%-m:%-l] %-a %-L %M"
LogFormat "%h %{GEOIP_COUNTRY_CODE}e %u [%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] \"%r\" %>s %b \
\"%{Referer}i\" \"%{User-Agent}i\" %v %A %p %R %{BALANCER_WORKER_ROUTE}e %X \"%{cookie}n\" \
%{UNIQUE_ID}e %{SSL_PROTOCOL}x %{SSL_CIPHER}x %I %O %{ratio}n%% \
%D %{ModSecTimeIn}e %{ApplicationTime}e %{ModSecTimeOut}e \
%{ModSecAnomalyScoreIn}e %{ModSecAnomalyScoreOut}e" extended

LogFormat "[%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] %{UNIQUE_ID}e %D \
PerfModSecInbound: %{TX.perf_modsecinbound}M \
PerfAppl: %{TX.perf_application}M \
PerfModSecOutbound: %{TX.perf_modsecoutbound}M \
TS-Phase1: %{TX.ModSecTimestamp1start}M-%{TX.ModSecTimestamp1end}M \
TS-Phase2: %{TX.ModSecTimestamp2start}M-%{TX.ModSecTimestamp2end}M \
TS-Phase3: %{TX.ModSecTimestamp3start}M-%{TX.ModSecTimestamp3end}M \
TS-Phase4: %{TX.ModSecTimestamp4start}M-%{TX.ModSecTimestamp4end}M \
TS-Phase5: %{TX.ModSecTimestamp5start}M-%{TX.ModSecTimestamp5end}M \
Perf-Phase1: %{PERF_PHASE1}M \
Perf-Phase2: %{PERF_PHASE2}M \
Perf-Phase3: %{PERF_PHASE3}M \
Perf-Phase4: %{PERF_PHASE4}M \
Perf-Phase5: %{PERF_PHASE5}M \
Perf-ReadingStorage: %{PERF_SREAD}M \
Perf-WritingStorage: %{PERF_SWRITE}M \
Perf-GarbageCollection: %{PERF_GC}M \
Perf-ModSecLogging: %{PERF_LOGGING}M \
Perf-ModSecCombined: %{PERF_COMBINED}M" perflog

LogLevel                      debug
ErrorLog                      logs/error.log
CustomLog                     logs/access.log extended
CustomLog                     logs/modsec-perf.log perflog env=write_perflog

# == ModSec Base Configuration

SecRuleEngine                 On

SecRequestBodyAccess          On
SecRequestBodyLimit           10000000
SecRequestBodyNoFilesLimit    64000

SecResponseBodyAccess         On
SecResponseBodyLimit          10000000

SecPcreMatchLimit             15000
SecPcreMatchLimitRecursion    15000

SecTmpDir                     /tmp/
SecDataDir                    /tmp/
SecUploadDir                  /tmp/

SecDebugLog                   /apache/logs/modsec_debug.log
SecDebugLogLevel              0

SecAuditEngine                RelevantOnly
SecAuditLogRelevantStatus     "^(?:5|4(?!04))"
SecAuditLogParts              ABIJEFHKZ

SecAuditLogType               Concurrent
SecAuditLog                   /apache/logs/modsec_audit.log
SecAuditLogStorageDir         /apache/logs/audit/

SecDefaultAction              "phase:1,pass,log,tag:'Local Lab Service'"



# == ModSec Rule ID Namespace Definition
# Service-specific before Core-Rules:    10000 -  49999
# Service-specific after Core-Rules:     50000 -  79999
# Locally shared rules:                  80000 -  99999
#  - Performance:                        90000 -  90199
# Recommended ModSec Rules (few):       200000 - 200010
# OWASP Core-Rules:                     900000 - 999999


# === ModSec timestamps at the start of each phase (ids: 90000 - 90009)

SecAction "id:'90000',phase:1,nolog,pass,setvar:TX.ModSecTimestamp1start=%{DURATION}"
SecAction "id:'90001',phase:2,nolog,pass,setvar:TX.ModSecTimestamp2start=%{DURATION}"
SecAction "id:'90002',phase:3,nolog,pass,setvar:TX.ModSecTimestamp3start=%{DURATION}"
SecAction "id:'90003',phase:4,nolog,pass,setvar:TX.ModSecTimestamp4start=%{DURATION}"
SecAction "id:'90004',phase:5,nolog,pass,setvar:TX.ModSecTimestamp5start=%{DURATION}"
                      
# SecRule REQUEST_FILENAME "@beginsWith /" "id:'90005',phase:5,t:none,nolog,noauditlog,pass,\
# setenv:write_perflog"



# === ModSec Recommended Rules (in modsec src package) (ids: 200000-200010)

SecRule REQUEST_HEADERS:Content-Type "text/xml" \
  "id:'200000',phase:1,t:none,t:lowercase,pass,nolog,ctl:requestBodyProcessor=XML"

SecRule REQBODY_ERROR "!@eq 0" \
  "id:'200001',phase:2,t:none,deny,status:400,log,msg:'Failed to parse request body.',\
  logdata:'%{reqbody_error_msg}',severity:2"

SecRule MULTIPART_STRICT_ERROR "!@eq 0" \
"id:'200002',phase:2,t:none,log,deny,status:403, \
msg:'Multipart request body failed strict validation: \
PE %{REQBODY_PROCESSOR_ERROR}, \
BQ %{MULTIPART_BOUNDARY_QUOTED}, \
BW %{MULTIPART_BOUNDARY_WHITESPACE}, \
DB %{MULTIPART_DATA_BEFORE}, \
DA %{MULTIPART_DATA_AFTER}, \
HF %{MULTIPART_HEADER_FOLDING}, \
LF %{MULTIPART_LF_LINE}, \
SM %{MULTIPART_MISSING_SEMICOLON}, \
IQ %{MULTIPART_INVALID_QUOTING}, \
IP %{MULTIPART_INVALID_PART}, \
IH %{MULTIPART_INVALID_HEADER_FOLDING}, \
FL %{MULTIPART_FILE_LIMIT_EXCEEDED}'"

SecRule TX:/^MSC_/ "!@streq 0" \
  "ID:'200004',phase:2,t:none,deny,status:500,\
  msg:'ModSecurity internal error flagged: %{MATCHED_VAR_NAME}'"


# === ModSec Core Rules Base Configuration (ids: 900000-900999)

Include    /apache/conf/crs/crs-setup.conf

SecAction "id:900110,phase:1,pass,nolog,\
  setvar:tx.inbound_anomaly_score_threshold=1000,\
  setvar:tx.outbound_anomaly_score_threshold=1000"

SecAction "id:900000,phase:1,pass,nolog,\
  setvar:tx.paranoia_level=1"


# === ModSec Core Rules: Runtime Exclusion Rules
#                        order by id of ignored rule (ids: 10000-49999)

# ...


# === ModSecurity Core Rules Inclusion

Include    /apache/conf/crs/rules/*.conf


# === ModSec Core Rules: Config Time Exclusion Rules (no ids)

# ...


# === ModSec Timestamps at the End of Each Phase (ids: 90010 - 90019)

SecAction "id:'90010',phase:1,pass,nolog,setvar:TX.ModSecTimestamp1end=%{DURATION}"
SecAction "id:'90011',phase:2,pass,nolog,setvar:TX.ModSecTimestamp2end=%{DURATION}"
SecAction "id:'90012',phase:3,pass,nolog,setvar:TX.ModSecTimestamp3end=%{DURATION}"
SecAction "id:'90013',phase:4,pass,nolog,setvar:TX.ModSecTimestamp4end=%{DURATION}"
SecAction "id:'90014',phase:5,pass,nolog,setvar:TX.ModSecTimestamp5end=%{DURATION}"


# === ModSec performance calculations and variable export (ids: 90100 - 90199)

SecAction "id:90100,phase:5,pass,nolog,\
  setvar:TX.perf_modsecinbound=%{PERF_PHASE1},\
  setvar:TX.perf_modsecinbound=+%{PERF_PHASE2},\
  setvar:TX.perf_application=%{TX.ModSecTimestamp3start},\
  setvar:TX.perf_application=-%{TX.ModSecTimestamp2end},\
  setvar:TX.perf_modsecoutbound=%{PERF_PHASE3},\
  setvar:TX.perf_modsecoutbound=+%{PERF_PHASE4},\
  setenv:ModSecTimeIn=%{TX.perf_modsecinbound},\
  setenv:ApplicationTime=%{TX.perf_application},\
  setenv:ModSecTimeOut=%{TX.perf_modsecoutbound},\
  setenv:ModSecAnomalyScoreIn=%{TX.anomaly_score},\
  setenv:ModSecAnomalyScoreOut=%{TX.outbound_anomaly_score}"

SSLCertificateKeyFile   /etc/ssl/private/ssl-cert-snakeoil.key
SSLCertificateFile      /etc/ssl/certs/ssl-cert-snakeoil.pem

SSLProtocol             All -SSLv2 -SSLv3
SSLCipherSuite          'kEECDH+ECDSA kEECDH kEDH HIGH +SHA !aNULL !eNULL !LOW !MEDIUM !MD5 !EXP !DSS \
!PSK !SRP !kECDH !CAMELLIA !RC4'
SSLHonorCipherOrder     On

SSLRandomSeed           startup file:/dev/urandom 2048
SSLRandomSeed           connect builtin

DocumentRoot		/apache/htdocs

<Directory />
      
	Require all denied

	Options SymLinksIfOwnerMatch
	AllowOverride None

</Directory>

<VirtualHost 127.0.0.1:80>
      
      <Directory /apache/htdocs>

        Require all granted

        Options None
        AllowOverride None

      </Directory>

</VirtualHost>

<VirtualHost 127.0.0.1:443>
    
      SSLEngine On

      <Directory /apache/htdocs>

              Require all granted

              Options None
              AllowOverride None

      </Directory>

</VirtualHost>

```


We have embedded the core rules and are now ready for test operation. The rules inspect requests and responses. They also trigger alarms, but will not block any requests, because the limits have been set very high. Let's give it a shot.

###Step 3: Triggering alarms for testing purposes

For starters, we will do something easy. It is a request that will trigger exactly one rule:

```bash
$> curl localhost/index.html?exec=/bin/bash
<html><body><h1>It works!</h1></body></html>
```
We have not been blocked, but let's check the logs to see if anything happened:

```bash
$> tail -1 /apache/logs/access.log
127.0.0.1 - - [2016-10-25 08:40:01.881647] "GET /index.html?exec=/bin/bash HTTP/1.1" 200 48 "-" "curl/7.35.0" localhost 127.0.0.1 40080 - - + "-" WA7@QX8AAQEAABC4maIAAAAV - - 98 234 -% 7672 2569 117 479 5 0
```

It's a standard `GET` request with a status 200. The interesting bit is the second field from the end. This is the inbound anomaly score of the request. Our submission of `/bin/bash` as parameter got us a score of 5. This is considered a critical rule violation by the Core Rules. An error is set at 4, a warning at 3 and a notice at 2. However, if you look over the rules, most of them score as critical violations with a score of 5.

But now we want to know what rule triggered the alert. We could simply tail the error log, but let's use the unique ID to get all the messages associated with our request. The unique ID was displayed in the access log, this is thus very simple:

```bash
[2016-10-25 08:40:01.881938] [authz_core:debug] 127.0.0.1:42732 WA7@QX8AAQEAABC4maIAAAAV AH01626: authorization result of Require all granted: granted
[2016-10-25 08:40:01.882000] [authz_core:debug] 127.0.0.1:42732 WA7@QX8AAQEAABC4maIAAAAV AH01626: authorization result of <RequireAny>: granted
[2016-10-25 08:40:01.884172] [-:error] 127.0.0.1:42732 WA7@QX8AAQEAABC4maIAAAAV [client 127.0.0.1] ModSecurity: Warning. Matched phrase "/bin/bash" at ARGS:exec. [file "/apache/conf/crs/rules/REQUEST-932-APPLICATION-ATTACK-RCE.conf"] [line "448"] [id "932160"] [rev "1"] [msg "Remote Command Execution: Unix Shell Code Found"] [data "Matched Data: /bin/bash found within ARGS:exec: /bin/bash"] [severity "CRITICAL"] [ver "OWASP_CRS/3.0.0"] [maturity "1"] [accuracy "8"] [tag "application-multi"] [tag "language-shell"] [tag "platform-unix"] [tag "attack-rce"] [tag "OWASP_CRS/WEB_ATTACK/COMMAND_INJECTION"] [tag "WASCTC/WASC-31"] [tag "OWASP_TOP_10/A1"] [tag "PCI/6.5.2"] [hostname "localhost"] [uri "/index.html"] [unique_id "WA7@QX8AAQEAABC4maIAAAAV"]
```

The authorization modules reports in the log file since we are running on level debug. But on the third line, we see the rule alert we are looking for. Let's look at this in detail. The core rules messages contain much more information than default messages, making it worthwhile to discuss the log format once more.

The beginning of the line consists of the Apache-specific parts such as the timestamp and the severity of the message as the Apache server sees it. *ModSecurity* messages are always set to *error* level. ModSecurity's alert format and the Apache error log format we configured lead to some redundancy. The client IP address with the source port number and the unique ID of the request are fields written by Apache. The square bracket with the same client IP address again marks the start of ModSecurity's alert message. The characteristic marker is `ModSecurity: Warning`. It describes a rule being triggered without blocking the request. The alert only raised the anomaly score. It is very easy to distinguish between the triggering of alarms and actual blocking in the Apache error log. Particularly since the individual core rules, as we have seen, increase the anomaly score, but they do not trigger a blockade. The blockade itself is performed by a separate blocking rule taking the limit into account. But given the insanely high limit, this is not expected to appear anytime soon. ModSecurity logs normal rule violations in the error log as *ModSecurity. Warning ...*, and blockades will be logged as *ModSecurity. Access denied ...*. A *warning* never has any direct impact on the client. Unless you see the *Access denied ...*, the client was unaffected.

What comes next? A reference to the pattern found in the request. The specific phrase `/bin/bash` was found in the argument `exec`. Then comes a series of parameters that always have the same pattern: They are within square brackets and have their own identifier. First comes the *file* identifier. It shows us the file in which the rule that triggered the alarm is defined. This is followed by *line* for the line number in the file. The *id* parameter appears more important to me. The rule in question, `932160`, out of the set of rules that defend against remote command execution in the 932.000 - 932.999 rule block. Then comes *rev* as a reference to the revision number of the rule. In core rules these parameters express how often the rule has been revised. If a modification is made to a rule, *rev* increases by one. *msg*, short for *message*, describes the type of attack detected. The relevant part of the request, the *exec* parameter appears in *data*. In my example this is obviously a case of *Remote Code Execution* (RCE).

At *ver* we come to the release of the core rule set, followed by *maturity*, a reference to the quality of the rule. Higher *maturity* indicates that we can trust this rule, because it is in widespread use and has caused very few problems. However, low *maturity* is likely to indicate an experimental rule. This is why the value 1 appears only six times in the *core rules*, whereas in the version being used 116 rules have a value of 8 and 99 rules are assumed to have a maturity of 9. *Accuracy*, the precision of the rule, behaves similar to *maturity*. This is an optional value the author of the rule defined when writing the rule. There are no low values in the system of rules, 8 is the most frequent value (144 times), 9 is widespread (82). These additional notes in the log message are for documentation purposes only. In my experience they are of little relevance and hardly ever change between *Core Rules* releases.

What follows is a series of *tags* assigned to the rule. It is therefore being included along with every rule violation. Afterwards follow several tags from the *Core Rule Set*, classifying the type of attack. These references can, for example, be used for analysis and statistics. Towards the end of the alarm come three additional values, *hostname*, *uri* and *unique_id*, that more clearly specify the request (the *unique_id* was already listed early on the log line by Apache itself, so repeating it here is somewhat redundant). 

With this, we have covered the full alert message that led to the inbound anomaly score of 5. That was only a single request with a single alert. Let's generate more alerts. *Nikto* is a simple tool that can help us in this situation. It's a security scanner that has been around for ages. It's not very proficient, but it is fast and easy to use. Just the right tool to generate alerts for us. *Nikto* may still have to be installed. The scanner is however included in most distributions.

```bash
$> nikto -h localhost
- Nikto v2.1.4
---------------------------------------------------------------------------
+ Target IP:          127.0.0.1
+ Target Hostname:    localhost
+ Target Port:        80
+ Start Time:         2016-10-26 10:07:07
---------------------------------------------------------------------------
+ Server: Apache
+ No CGI Directories found (use '-C all' to force check all possible dirs)
+ ETag header found on server, fields: 0x30 0x53ab921464f15 
+ Allowed HTTP Methods: GET, HEAD, POST, OPTIONS 
+ /login.php: Admin login page/section found.
+ 6448 items checked: 0 error(s) and 3 item(s) reported on remote host
+ End Time:           2016-10-26 10:07:57 (50 seconds)
---------------------------------------------------------------------------
+ 1 host(s) tested
```

This scan should have triggered numerous *ModSecurity alarms* on the server. Let’s take a close look at the *Apache error log*. In my case there were over 7,300 entries in the error log. Combine this with the authorization messages and infos on many 404s (nikto probes for files that do not exist on the server) and you end up with error log growing fast. The single nikto run resulted in a logfile of 8.8 MB. Looking over the audit log tree reveals 78 MB of logs. It's obvious: you need to keep a close eye on these log files or your server will collapse.

###Step 4: Analyzing anomaly scores

We are now facing 7,300 alerts. And even if the format of the entries in the error log may be clear, without a tool they are very hard to read, let alone analyze. A simple remedy is to use a few *shell aliases*, which extract individual pieces of information from the entries. They are stored in the alias file we discussed in the log format Tutorial 5.

```
$> cat ~/.apache-modsec.alias
...
alias meldata='grep -o "\[data [^]]*" | cut -d\" -f2'
alias melfile='grep -o "\[file [^]]*" | cut -d\" -f2'
alias melhostname='grep -o "\[hostname [^]]*" | cut -d\" -f2'
alias melid='grep -o "\[id [^]]*" | cut -d\" -f2'
alias melip='grep -o "\[client [^]]*" | cut -b9-'
alias melline='grep -o "\[line [^]]*" | cut -d\" -f2'
alias melmatch='grep -o " at [^\ ]*\. \[file" | sed -e "s/\. \[file//" | cut -b5-'
alias melmsg='grep -o "\[msg [^]]*" | cut -d\" -f2'
alias meltimestamp='cut -b2-25'
alias melunique_id='grep -o "\[unique_id [^]]*" | cut -d\" -f2'
alias meluri='grep -o "\[uri [^]]*" | cut -d\" -f2'
...
$> source ~/.apache-modsec.alias 
```

These abbreviations all start with the prefix *mel*, short for *ModSecurity error log*. Then comes the field name. Let’s try it out to output the rule IDs in the messages.

```
$> cat logs/error.log | melid | tail
941160
920440
920440
911100
920100
930100
930110
930110
930120
932160
```

This seems to do the job. So let’s extend the example in a few steps:

```
$> cat logs/error.log | melid | sort | uniq -c | sort -n
      1 920220
      1 920290
      1 921150
      1 932115
      2 920280
      2 941140
      3 942270
      4 920420
      4 933150
      6 932110
      9 911100
     11 920100
     12 942100
     13 920430
     13 932100
     13 932105
     15 941170
     15 941210
     17 920170
     35 932150
     67 933130
     70 933160
    115 941180
    136 920270
    139 932160
    141 931110
    191 930100
    219 920440
    219 930120
    246 941110
    248 941100
    249 941160
    531 930110
   2274 931120
   2340 913120
$> cat logs/error.log | melid | sort | uniq -c | sort -n | while read STR; do echo -n "$STR "; \
ID=$(echo "$STR" | sed -e "s/.*\ //"); grep $ID logs/error.log | head -1 | melmsg; done
1 920220 URL Encoding Abuse Attack Attempt
1 920290 Empty Host Header
1 921150 HTTP Header Injection Attack via payload (CR/LF deteced)
1 932115 Remote Command Execution: Windows Command Injection
2 920280 Request Missing a Host Header
2 941140 XSS Filter - Category 4: Javascript URI Vector
3 942270 Looking for basic sql injection. Common attack string for mysql, oracle and others.
4 920420 Request content type is not allowed by policy
4 933150 PHP Injection Attack: High-Risk PHP Function Name Found
6 932110 Remote Command Execution: Windows Command Injection
9 911100 Method is not allowed by policy
11 920100 Invalid HTTP Request Line
12 942100 SQL Injection Attack Detected via libinjection
13 920430 HTTP protocol version is not allowed by policy
13 932100 Remote Command Execution: Unix Command Injection
13 932105 Remote Command Execution: Unix Command Injection
15 941170 NoScript XSS InjectionChecker: Attribute Injection
15 941210 IE XSS Filters - Attack Detected.
17 920170 GET or HEAD Request with Body Content.
35 932150 Remote Command Execution: Direct Unix Command Execution
67 933130 PHP Injection Attack: Variables Found
70 933160 PHP Injection Attack: High-Risk PHP Function Call Found
115 941180 Node-Validator Blacklist Keywords
136 920270 Invalid character in request (null character)
139 932160 Remote Command Execution: Unix Shell Code Found
141 931110 Possible Remote File Inclusion (RFI) Attack: Common RFI Vulnerable Parameter Name used w/URL Payload
191 930100 Path Traversal Attack (/../)
219 920440 URL file extension is restricted by policy
219 930120 OS File Access Attempt
246 941110 XSS Filter - Category 1: Script Tag Vector
248 941100 XSS Attack Detected via libinjection
249 941160 NoScript XSS InjectionChecker: HTML Injection
531 930110 Path Traversal Attack (/../)
2274 931120 Possible Remote File Inclusion (RFI) Attack: URL Payload Used w/Trailing Question Mark Character (?)
2340 913120 Found request filename/argument associated with security scanner
```

This we can work with. But it’s perhaps necessary to explain the *one-liners*. We extract the rule IDs from the *error log*, then *sort* them, put them together in a list of found IDs (*uniq -c*) and sort again by the numbers found. That’s the first *one-liner*. A relationship between the individual rules is still lacking, because there’s not much we can do with the ID number yet. We get the names from the *error log* again by looking through the previously run test line-by-line in a loop. We show what we have in this loop (`$STR`). Then we have to separate the number of found items and the IDs again. This is done using an embedded sub-command (`ID=$(echo "$STR" | sed -e "s/.*\ //")`). We then use the IDs we just found to search the *error log* once more for an entry, but take only the first one, extract the *msg* part and display it. Done.

Depending on computing power this may take just a few seconds or a few minutes. You might now think that it would be better to define an additional alias to determine the ID and description of the rule in a single step. This puts us on the wrong path, though, because there are rules that contain dynamic parts in and following the brackets (anomaly scores in the rules checking the threshold with rule ID 949110 and 980130!). We of course want to combine these rules putting them together in order to map the rule only once. So, to really simplify analysis we have to get rid of the dynamic items. Here’s an additional *alias* that implements this idea. It is part of the *.apache-modsec.alias* file you are already familiar with.

```bash
alias melidmsg='grep -o "\[id [^]]*\].*\[msg [^]]*\]" | sed -e "s/\].*\[/] [/" -e "s/\[msg //" | \
cut -d\  -f2- | tr -d "\]\"" | sed -e "s/(Total .*/(Total ...) .../"'
```

```bash
$> cat logs/error.log | melidmsg | sucs
      1 920220 URL Encoding Abuse Attack Attempt
      1 920290 Empty Host Header
      1 921150 HTTP Header Injection Attack via payload (CR/LF deteced)
      1 932115 Remote Command Execution: Windows Command Injection
      2 920280 Request Missing a Host Header
      2 941140 XSS Filter - Category 4: Javascript URI Vector
      3 942270 Looking for basic sql injection. Common attack string for mysql, oracle and others.
      4 920420 Request content type is not allowed by policy
      4 933150 PHP Injection Attack: High-Risk PHP Function Name Found
      6 932110 Remote Command Execution: Windows Command Injection
      9 911100 Method is not allowed by policy
     11 920100 Invalid HTTP Request Line
     12 942100 SQL Injection Attack Detected via libinjection
     13 920430 HTTP protocol version is not allowed by policy
     13 932100 Remote Command Execution: Unix Command Injection
     13 932105 Remote Command Execution: Unix Command Injection
     15 941170 NoScript XSS InjectionChecker: Attribute Injection
     15 941210 IE XSS Filters - Attack Detected.
     17 920170 GET or HEAD Request with Body Content.
     35 932150 Remote Command Execution: Direct Unix Command Execution
     67 933130 PHP Injection Attack: Variables Found
     70 933160 PHP Injection Attack: High-Risk PHP Function Call Found
    115 941180 Node-Validator Blacklist Keywords
    136 920270 Invalid character in request (null character)
    139 932160 Remote Command Execution: Unix Shell Code Found
    141 931110 Possible Remote File Inclusion (RFI) Attack: Common RFI Vulnerable Parameter Name used w/URL Payload
    191 930100 Path Traversal Attack (/../)
    219 920440 URL file extension is restricted by policy
    219 930120 OS File Access Attempt
    246 941110 XSS Filter - Category 1: Script Tag Vector
    248 941100 XSS Attack Detected via libinjection
    249 941160 NoScript XSS InjectionChecker: HTML Injection
    531 930110 Path Traversal Attack (/../)
   2274 931120 Possible Remote File Inclusion (RFI) Attack: URL Payload Used w/Trailing Question Mark Character (?)
   2340 913120 Found request filename/argument associated with security scanner
```

So that's something we can work with. It proofs that the Core Rules detected a lot of malign requests and we now have an idea which rules played a role in this. The rule triggered the most frequently, 913120, is no surprise in this regard and when you look upwards in the output, this all makes a lot of sense.



###Step 5: Evaluating false alarms

So *Nikto* scan set off thousands of alarms. They were likely justified. In the normal use of *ModSecurity* things are different. The Core Rules are designed and optimised to have as few false alarms as positives. But in real life, there are going to be false positives sooner or later. Depending on application, a normal installation will also see alarms and in my experience most of them are false. And when you raise the paranoia level to become more vigilant towards attacks, then the number of false positives will raise. Actually, it will raise steeply when you move to PL 3 or 4. So steeply in fact, some would call it exploding.

In order to run smoothly, the configuration has to first be fine tuned. Legitimate requests and exploitation attempts need to be distinct. We want to achieve a high degree of separation between the two. We wish to configure *ModSecurity* and the CRS so the engine knows exactly how to distinguish between legitimate requests and attacks.

False alarms are possible in both directions. Attacks that are not detected are called *false negatives*. The *core rules* are strict and careful to keep the number of *false negatives* low. An attacker would have to possess a great deal of savvy to circumvent the system of rules; especially at higher paranoia levels. Unfortunately, this strictness also results in alarms being triggered for normal requests. There are a lot of *false positives* like these. It is commonly the case that at a low degree of separation you either get a lot of *false negatives* or a lot of *false positives*. Reducing the number of *false negatives* leads to an increase in *false positives*. Both correlate highly with one another.

We have to overcome this link: We want to increase the degree of separation in order to reduce the number of *false positives* without increasing the number of *false negatives*. We can do this by fine tuning the system of rules in a few places. But first we need to have a clear picture of the current situation: How many *false positives* are there and which of the rules are being violated in a particular context? We need a plan and a goal: How many *false positives* are we willing to allow on the system? Reducing them to zero will be extremely difficult to do, but percentages are something we can work with. A possible target would be: 99.9999% of legitimate requests should pass without being blocked. This is realistic, but involves a bit of work depending on the application.

To reach such a goal we will need one or two tools to help us get a good footing. Specifically, we want to find out the *anomaly scores* the different requests to the server have been assigned and which of the rules have actually been violated. We have seen that the access log reports the anomaly scores of the requests thanks to the special format introduced in one of the previous tutorials. We now want to present these data in a suitable form.

In Tutorial 5 we worked with a sample log file containing 10,000 entries. We’ll be using this log file again here: [tutorial-5-example-access.log](https://www.netnea.com/apache-tutorials/git/laboratory/tutorial-5/tutorial-5-example-access.log). The file comes from a real server, but the IP addresses, server names and paths have been simplified or rewritten. However, the information we need for our analysis is still there. Let’s have a look at the distribution of *anomaly scores*:

```
$> egrep -o "[0-9-]+ [0-9-]+$" tutorial-5-example-access.log | cut -d\  -f1 | sucs
      1 21
      2 41
      8 5
     11 2
     17 3
     41 -
   9920 0
$> egrep -o "[0-9-]+$" tutorial-5-example-access.log | sucs
     41 -
   9959 0
```

The first command line reads the inbound *anomaly score*. It’s the second-to-last value in the *access log line*. We take the two last values (*egrep*) and then *cut* the first one out. We then sort the results using the familiar *sucs* alias. The outbound *anomaly score* is the last value in the *log line*. This is why there is no *cut* command on the second command line.

The results give us an idea about the situation: The great majority of requests pass the *ModSecurity module* with no rule violation. 80 requests violated one or more rule. This is not a standard situation. In fact, I provoked additional false alarms to give us something to look at. The Core Rules are so optimised these days, that you need a lot of traffic to get a reasonable amount of alerts - or you need to raise the paranoia level very high on an untuned system.

A score of 41 appears twice, corresponding to a high number of serious rule infractions. This is very common in practice. In 41 cases we didn’t get any score for the server’s responses. These are log entries of empty requests in which a connection with the client was established, but no request was made. We have taken this possibility into account in the regular expression using *egrep* and are also taking account of the default value "-". Besides these empty entries, nothing else is conspicuous at all. This is typical, if a bit high. In all likelihood we will be seeing a fair number of violations from the requests and very few alarms from the responses.

But this still doesn’t give us the right idea about the *tuning steps* that would be needed to run this install smoothly. To present this information in suitable form I have prepared a script that analyzes *anomaly scores*. [modsec-positive-stats.rb](https://www.netnea.com/apache-tutorials/git/laboratory/bin/modsec-positive-stats.rb). Applied to the log file, the script delivers the following result:

```
$> cat tutorial-5-example-access.log  | egrep -o "[0-9-]+ [0-9-]+$" | tr " " ";" | modsec-positive-stats.rb
INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |     41 |   0.4100% |   0.4100% |  99.5900%
Reqs with incoming score of   0 |   9920 |  99.2000% |  99.6100% |   0.3900%
Reqs with incoming score of   1 |      0 |   0.0000% |  99.6100% |   0.3900%
Reqs with incoming score of   2 |     11 |   0.1100% |  99.7200% |   0.2800%
Reqs with incoming score of   3 |     17 |   0.1699% |  99.8900% |   0.1100%
Reqs with incoming score of   4 |      0 |   0.0000% |  99.8900% |   0.1100%
Reqs with incoming score of   5 |      8 |   0.0800% |  99.9700% |   0.0300%
Reqs with incoming score of   6 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of   7 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of   8 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of   9 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  10 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  11 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  12 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  13 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  14 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  15 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  16 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  17 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  18 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  19 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  20 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  21 |      1 |   0.0100% |  99.9800% |   0.0200%
Reqs with incoming score of  22 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  23 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  24 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  25 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  26 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  27 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  28 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  29 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  30 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  31 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  32 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  33 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  34 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  35 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  36 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  37 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  38 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  39 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  40 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  41 |      2 |   0.0200% | 100.0000% |   0.0000%

Average:   0.0217        Median   0.0000         Standard deviation   0.6490


OUTGOING                     Num of req. | % of req. |  Sum of % | Missing %
Number of outgoing req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |     41 |   0.4100% |   0.4100% |  99.5900%
Reqs with outgoing score of   0 |   9959 |  99.5900% | 100.0000% |   0.0000%

Average:   0.0000        Median   0.0000         Standard deviation   0.0000
```

The script divides the incoming from the outgoing *anomaly scores*. The incoming ones are handled first. At first, one line describes how often an empty *anomaly score* has been found (*empty incoming score*). In our case this was the 41 times we saw before. Then comes the statement about *score 0*: 9920 requests. This is coverage of 99.2%. Together with the empty scores this is already coverage of 99.61% (*Sum of %*). 0.39% had a higher *anomaly score* (*Missing %*). Above we set out to have 99.99% of requests able to pass the server. We are just 0.38% or 38 requests away from this target. The next *anomaly score* is 2. It appears 11 times or 0.11%. The 3 appears 17 times and a score of 5 8 times. All in all, we are at 99.97%. Then there is one request with a score of 21 and finally 2 requests with 41. To achieve 99.99% coverage we have get to this limit (and, based on the log file, thus achieve 100% coverage).

There are probably some *false positives*. In practice, we have to make certain of this before we start fine tuning the rules. It would basically be wrong to assume a false positive based on a justified alarm and suppress the alarm in the future. Before tuning it must therefore be ensured that no attacks are present in the log file. This is not always very easy. Manual review helps, restricting to known IP addresses, testing/tuning on a test system separated from the internet, filtering the access log by country of origin for the IP address, etc.: It's a big topic and making general recommendations is difficult.

###Step 6: Suppressing false alarms: Disabling individual rules

The simple way of dealing with a *false positive* is to simply disable the rule. This takes very little effort, but is of course potentially risky, because the rule is not being disabled for just legitimate users, but for attackers as well. By completely disabling a rule we are thus restricting the capability of *ModSecurity*. Or, expressed more drastically, we’re pulling the teeth out of the *WAF*. This is not something we want in practice. Nevertheless, it is important to know how this simple method works.

FIXME: Above we saw a list of alarms we can use to provoke the *Nikto* security scanner. One rule, which *Nikto* along with legitimate browsers sometimes violate is 960015: Request Missing an Accept Header. Due to this rule, alarms on a normal server occur quite frequently. This is a reason for disabling the rule.

In our configuration file we have marked out two places to put the *ignore rules*. Once before the *core rules* and a second time after the *core rules*:

```bash
# === ModSecurity Ignore Rules Before Core Rules Inclusion; order by id of ignored rule (ids: 10000-49999)

...

# === ModSecurity Core Rules Inclusion

Include    conf/modsecurity-core-rules-latest/*.conf

# === ModSecurity Ignore Rules After Core Rules Inclusion; order by id of ignored rule (ids: 50000-79999)

...

```

We are suppressing rule *960015* in the section above. Before we do this, we provoke an alarm for the rule:

```bash
$> curl -v -H "Accept: " http://localhost/index.html
...
> GET /index.html HTTP/1.1
> User-Agent: curl/7.32.0
> Host: localhost
...
$> tail /apache/logs/error.log
...
[Tue Dec 10 06:41:41 2013] [error] [client 127.0.0.1] ModSecurity: Warning. Operator EQ matched 0 at REQUEST_HEADERS. [file "/apache/conf/modsecurity-core-rules-latest/modsecurity_crs_21_protocol_anomalies.conf"] [line "47"] [id "960015"] [rev "1"] [msg "Request Missing an Accept Header"] [severity "NOTICE"] [ver "OWASP_CRS/2.2.8"] [maturity "9"] [accuracy "9"] [tag "Local Lab Service"] [tag "OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER_ACCEPT"] [tag "WASCTC/WASC-21"] [tag "OWASP_TOP_10/A7"] [tag "PCI/6.5.10"] [hostname "localhost"] [uri "/index.html"] [unique_id "UqaplX8AAQEAABiYANYAAAAD"]
[Tue Dec 10 06:41:41 2013] [error] [client 127.0.0.1] ModSecurity: Warning. Operator LT matched 1000 at TX:inbound_anomaly_score. [file "/apache/conf/modsecurity-core-rules-latest/modsecurity_crs_60_correlation.conf"] [line "33"] [id "981203"] [msg "Inbound Anomaly Score (Total Inbound Score: 2, SQLi=, XSS=): Request Missing an Accept Header"] [tag "Local Lab Service"] [hostname "localhost"] [uri "/index.html"] [unique_id "UqaplX8AAQEAABiYANYAAAAD"]
```

We instructed *curl* to send a request with no *Accept header*. Using the *verbose* option (*-v*) we can perfectly control this behavior. The *error log* will then actually show the alarm that was provoked with the summary of *anomaly scores* on the lines below. The rule violation earned the request a score of 2. Now we’ll be suppressing the rule by writing an *ignore rule* in the configuration section provided for it before *Core Rules Inclusion*:

```bash
SecRule REQUEST_FILENAME "@beginsWith /" "phase:1,nolog,pass,t:none,id:10000,ctl:ruleRemoveById=960015"
```

We define a rule that first inspects the path. With the condition for the path *"/"*, the rule will of course always apply and the condition is therefore not needed. We prefer to set it this way nevertheless, because this base pattern can easily be used for different paths. Without a condition we would formulate it as *SecAction*. In phase 1 of our rule we define that we don’t want to log, but assign an ID to the beginning of our block (*10000*). Finally, we suppress rule *960015*. This is done via a control instruction (*ctl.*).

That was very important. Therefore, to summarize once again: We define a rule to suppress another rule. We use a pattern for this which lets us define a path as a condition. This enables us to disable rules for individual parts of an application. Only in those places where false alarms occur. This prevents us from disabling rules on the entire server, considering that the false alarm occurs only when processing one individual form, which is frequently the case. This would look something like this:

```
SecRule REQUEST_FILENAME "@beginsWith /app/submit.do" "phase:1,nolog,pass,t:none,id:10001,\
ctl:ruleRemoveById=960015"
```

We have now disabled a rule. For the entire service (*"/"*) or for a specific sub-path (*"/app/submit.do"*). Unfortunately, we have gone a bit blind with respect to these rules. We never know whether incoming requests would violate the rule. Because we aren’t always familiar with the applications on our servers in detail and if we now wait a year and think about whether we still need the *ignore rule*, we won’t have an answer for that. We have suppressed every message on the topic. It would be ideal if we could still observe when the rule takes effect, but without blocking the request and having the *anomaly score* remain unchanged. Increasing an *anomaly score* is done in the definition of the rule. In rule *960015* of the *core rules* this is solved as follows:

```
setvar:tx.inbound_anomaly_score=+%{tx.notice_anomaly_score}"
```

Here the value *tx.notice_anomaly_score* is added to the *inbound_anomaly_score* transaction variable. We have the option of changing the configuration of this rule without touching the rule file. We can’t suppress addition, but we can neutralize it by subtraction. However, this means another rule pattern in the form of a rule configured after the *core rules* are embedded.

```
...
SecRule REQUEST_FILENAME "@beginsWith /index.html" "chain,phase:2,log,pass,t:none,id:10004,\
	msg:'Adjusting inbound anomaly score for rule 960015'"
   SecRule "&TX:960015-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-REQUEST_HEADERS" "@ge 1" \
   	"setvar:tx.inbound_anomaly_score=-%{tx.notice_anomaly_score}"
...
```

Here we have two rules combined via the *chain* command. This means that the first rule formulates a condition and the second rule is only executed if the first condition is true. Another somewhat cryptic condition is formulated in the second rule. Specifically, we are looking if a specific variable is set, in particular *TX:960015-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-REQUEST_HEADERS*. This transaction variable was set by rule *960015* and indicates a match for rule 960015. So, if we find this variable this means that rule 960015 was applied. In this case we again reduce the *inbound anomaly score* by the same value the rule increased it. We thus neutralize the effect of the rule without suppressing the message itself.

Afterwards, for the *curl* request presented above this results in two entries in the *error log*:

```bash
[2015-11-08 08:16:19.215089] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. Operator EQ matched 0 at REQUEST_HEADERS. [file "/modsecurity-core-rules/modsecurity_crs_21_protocol_anomalies.conf"] [line "47"] [id "960015"] [rev "1"] [msg "Request Missing an Accept Header"] [severity "NOTICE"] [ver "OWASP_CRS/2.2.9"] [maturity "9"] [accuracy "9"] [tag "Local Lab Service"] [tag "OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER_ACCEPT"] [tag "WASCTC/WASC-21"] [tag "OWASP_TOP_10/A7"] [tag "PCI/6.5.10"] [hostname "localhost"] [uri "/app/submit.do"] [unique_id "Vj72w38AAQEAADwHNSoAAAAA"]
[2015-11-08 08:16:19.220263] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. Operator GE matched 1 at TX. [file "/apache/conf/httpd.conf_labor-06"] [line "187"] [id "10001"] [msg "Adjusting inbound anomaly score for rule 960015"] [tag "Local Lab Service"] [hostname "localhost"] [uri "/app/submit.do"] [unique_id "Vj72w38AAQEAADwHNSoAAAAA"]
```

The entry about the final *anomaly score* does not appear, because this value was reset to 0. All this means that we will now continue to be informed if a rule violation occurs, but the request will no longer be assigned an *anomaly score* based on this rule. In this sense, we have accepted the alarm.

These types of rules are demanding: While the first condition follows a familiar pattern, the second rule which includes the transaction variable involves a lot of writing: How do we get to the variable names and from where exactly do we know the score?

We can either get the variable names from the rule definitions in the *core rules* or stick with the *debug log* that we define at the highest level (*SecDebugLogLevel 9*):

```
$> sudo egrep "Set variable.*960015" logs/modsec_debug.log
[16/Dec/2013:10:16:11 +0100] [localhost/sid#1470170][rid#7fbc5c018e40][/app/submit.do][9] Set variable "tx.960015-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-REQUEST_HEADERS" to "0".
```

The *tx.960015-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-REQUEST_HEADERS* written here must be written in a rule as *TX:960015-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-REQUEST_HEADERS*, written exactly as we just did above. The *&* in front means that it’s not the variable itself being inspected, but the number of variables with this name: *1*. The exact value by which we have to subtract again in the *inbound anomaly score* is again found in the *debug log*:

```bash
$> sudo egrep -B9 "Set variable.*960015" logs/modsec_debug.log
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Setting variable: tx.anomaly_score=+%{tx.notice_anomaly_score}
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Recorded original collection variable: tx.anomaly_score = "0"
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Resolved macro %{tx.notice_anomaly_score} to: 2
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Relative change: anomaly_score=0+2
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Set variable "tx.anomaly_score" to "2".
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Setting variable: tx.%{rule.id}-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-%{matched_var_name}=%{matched_var}
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Resolved macro %{rule.id} to: 960015
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Resolved macro %{matched_var_name} to: REQUEST_HEADERS
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Resolved macro %{matched_var} to: 0
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Set variable "tx.960015-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-REQUEST_HEADERS" to "0"
```

Here we see in detail how *ModSecurity* performed its arithmetic functions. What’s interesting is the first line showing how the anomaly score is increased. It is increased by *tx.notice_anomaly_score*. We would also find this value in the definition of the *core rules*, but it’s easier to read here.

It can of course happen that a rule is violated multiple times. This means that multiple parameters are violating the same rule. We can also cover this case, at yet another level of complexity. In this case, *ModSecurity* writes a collection variable that includes the variable names: rule number and name with the suffix *-ARGS:<name>* added to it. For a *file injection rule* such as *950005* this results, for example, in *TX:950005-OWASP_CRS/WEB_ATTACK/FILE_INJECTION-ARGS:contact_form_name*. If we are dealing with two parameters that are violating this rule (say, for instance *contact_form_name* and *contact_form_address*), we use the following construct:

```bash
SecRule REQUEST_FILENAME "@beginsWith /app/submit.do" "chain,phase:2,log,t:none,pass,id:10003, \
	msg:'Adjusting inbound anomaly score for rule 950005'"
   SecRule "&TX:950005-OWASP_CRS/WEB_ATTACK/FILE_INJECTION-ARGS:contact_form_name" "@ge 1" \
   	"setvar:tx.inbound_anomaly_score=-%{tx.critical_anomaly_score}"

SecRule REQUEST_FILENAME "@beginsWith /submit.do" "chain,phase:2,log,pass,t:none,id:10004, \
	msg:'Adjusting inbound anomaly score for rule 950005'"
   SecRule "&TX:950005-OWASP_CRS/WEB_ATTACK/FILE_INJECTION-ARGS:contact_form_address" "@ge 1" \
   	"setvar:tx.inbound_anomaly_score=-%{tx.critical_anomaly_score}"
```

We can trigger the rule violation and change of anomaly value just configured with the following request:

```bash
$> curl -d "contact_form_name=/etc/passwd" -d "contact_form_address=/etc/passwd" \
	http://localhost/app/submit.do
...
$> tail -1 logs/access.log
127.0.0.1 - - [2015-11-08 08:25:46.950543] "POST /app/submit.do HTTP/1.1" 404 45 "-" \
"curl/7.46.0-DEV" localhost 127.0.0.1 80 - - "-" Vj74@n8AAQEAADydhKkAAAAE - - 219 231 \
-% 21734 19189 71 588 0 0
$> grep Vj74@n8AAQEAADydhKkAAAAE logs/error.log
...
[2015-11-08 08:25:46.961718] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. Pattern match "(?:\\\\b(?:\\\\.(?:ht(?:access|passwd|group)|www_?acl)|global\\\\.asa|httpd\\\\.conf|boot\\\\.ini)\\\\b|\\\\/etc\\\\/)" at ARGS:contact_form_address. [file "/modsecurity-core-rules/modsecurity_crs_40_generic_attacks.conf"] [line "205"] [id "950005"] [rev "3"] [msg "Remote File Access Attempt"] [data "Matched Data: /etc/ found within ARGS:contact_form_address: /etc/passwd"] [severity "CRITICAL"] [ver "OWASP_CRS/2.2.9"] [maturity "9"] [accuracy "9"] [tag "Local Lab Service"] [tag "OWASP_CRS/WEB_ATTACK/FILE_INJECTION"] [tag "WASCTC/WASC-33"] [tag "OWASP_TOP_10/A4"] [tag "PCI/6.5.4"] [hostname "localhost"] [uri "/app/submit.do"] [unique_id "Vj74@n8AAQEAADydhKkAAAAE"]
[2015-11-08 08:25:46.961953] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. Pattern match "(?:\\\\b(?:\\\\.(?:ht(?:access|passwd|group)|www_?acl)|global\\\\.asa|httpd\\\\.conf|boot\\\\.ini)\\\\b|\\\\/etc\\\\/)" at ARGS:contact_form_name. [file "/modsecurity-core-rules/modsecurity_crs_40_generic_attacks.conf"] [line "205"] [id "950005"] [rev "3"] [msg "Remote File Access Attempt"] [data "Matched Data: /etc/ found within ARGS:contact_form_name: /etc/passwd"] [severity "CRITICAL"] [ver "OWASP_CRS/2.2.9"] [maturity "9"] [accuracy "9"] [tag "Local Lab Service"] [tag "OWASP_CRS/WEB_ATTACK/FILE_INJECTION"] [tag "WASCTC/WASC-33"] [tag "OWASP_TOP_10/A4"] [tag "PCI/6.5.4"] [hostname "localhost"] [uri "/app/submit.do"] [unique_id "Vj74@n8AAQEAADydhKkAAAAE"]
[2015-11-08 08:25:46.970259] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. Operator GE matched 1 at TX. [file "/apache/conf/httpd.conf_labor-06"] [line "187"] [id "50001"] [msg "Adjusting inbound anomaly score for rule 950005"] [tag "Local Lab Service"] [hostname "localhost"] [uri "/app/submit.do"] [unique_id "Vj74@n8AAQEAADydhKkAAAAE"]
[2015-11-08 08:25:46.970320] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. Operator GE matched 1 at TX. [file "/apache/conf/httpd.conf_labor-06"] [line "190"] [id "50002"] [msg "Adjusting inbound anomaly score for rule 950005"] [tag "Local Lab Service"] [hostname "localhost"] [uri "/app/submit.do"] [unique_id "Vj74@n8AAQEAADydhKkAAAAE"]

```

As you see, we can instruct *ModSecurity* to apply the core rules without having to increase the score. But to be honest, you have to admit that the design of such a construct is extremely complex and error-prone. This is why I don’t use this technique in practice, but only suppress *false positives* by selectively disabling rules and for this reason am struggling with the blindness described at the beginning. 

There’s a very simple method for disabling the rules that we are not familiar with yet:

###Step 7: Suppressing false alarms: Disabling individual rules for specific parameters

Till now we have suppressed individual rules for specific paths. In practice there is a second case that at least quantitatively is very widespread: An individual parameter, typically a cookie, triggers rule violation regardless of path. Each individual request results in a rule violation. An initial look at the statistics can come as quite a shock. But only when you see how easy this is to handle does the situation settle down a bit. You’d have to disable the rule for the base path */* or manage to generally disable the rules for the affected parameter. This is done as follows:

```bash
SecRuleUpdateTargetById 950005 "!REQUEST_COOKIES:basket_id"
```

This directive, that has to be configured after loading the *core rules*, matches the *target list* in rule 950005. This means that the cookie *basket_id* should no longer be inspected by rule 950005. This again results in blindness, but a cookie can be very easily checked at a later point in time as to whether the rules related to it are still relevant.

For form parameters we shouldn’t proceed so generally that we disable it for the entire service. There is however another rule pattern closely based on this example, but which is only effective on a single path for an individual parameter:

```bash
SecRule REQUEST_FILENAME "@beginsWith /app/submit.do" \
	"phase:2,nolog,pass,t:none,id:10002,ctl:ruleRemoveTargetById=950005;ARGS:contact_form_name"
```

We disable the handling of the *contact_form_name* parameter via rule *950005* for the path */app/submit.do*.. This does the job right and in my experience is the preferred way to suppress an individual false positive for a parameter.

Using the different methods to design *ignore rules* gives us the tools we need to work through the *false positives* one by one. Being able to work quickly requires experience and helpful tools which we will becoming familiar with in the next tutorial.

###Step 8: Readjusting the anomaly limit

You now use the patterns for *ignore rules* described above to work through the various *false positives*. This work is very complex. However, with the goal of protecting the application in detail, it is most certainly worthwhile. What should however be considered is the degree to which the *false positives* are to be eliminated. A typical target value is something such as blocking a request that violated a rule on a level lower than *critical*. This means setting the *anomaly limit* to 5. Now, every request that violates a critical rule is assigned a score of a least 5 and is blocked in the end. A service tuned this way could receive an *access log* analysis using the following pattern:

```
$> egrep  -o "[0-9]+ [0-9]+$" logs/access.log   | ./modsec-positive-stats.rb 
INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with incoming score of   0 |   9970 |  99.7000% |  99.7000% |   0.3000%
Reqs with incoming score of   1 |      4 |   0.0400% |  99.7400% |   0.2600%
Reqs with incoming score of   2 |     21 |   0.2100% |  99.9500% |   0.0500%
Reqs with incoming score of   3 |      0 |   0.0000% |  99.9500% |   0.0500%
Reqs with incoming score of   4 |      4 |   0.0400% |  99.9900% |   0.0100%
Reqs with incoming score of   5 |      1 |   0.0100% | 100.0000% |   0.0000%

Average:   0.0067        Median   0.0000         Standard deviation   0.1329


OUTGOING                     Num of req. | % of req. |  Sum of % | Missing %
Number of outgoing req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. outgoing score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with outgoing score of   0 |  10000 | 100.0000% | 100.0000% |   0.0000%

Average:   0.0000        Median   0.0000         Standard deviation   0.0000
```

Of 10,000 requests, 9,999 have an *anomaly score* of 4 or lower. This is a fine tuned service. We can thus reduce the *inbound anomaly score limit* increased at the beginning. If we want to be notified of critical rule violations, we set the limits as follows:

```
...
SecAction "id:'900002',phase:1,t:none,setvar:tx.inbound_anomaly_score_level=5,nolog,pass"
SecAction "id:'900003',phase:1,t:none,setvar:tx.outbound_anomaly_score_level=5,nolog,pass"
...
```

We do the same with the *outbound anomaly score*. In practice, you’ll have to be a bit more nuanced.

###Step 9: Summary of the ways of combating false positives

We have become familiar with four different ways of suppressing a false alarm. I’m presenting them here again along with specific examples:


**Case 1 : Disabling a rule completely** </br>

```bash
# ModSecurity Rule Exclusion: 920350 Host header is a numeric IP address
SecRuleRemoveById 920350
```

This is the most simple form of an exclusion rule that disables a rule completely. 

The directive has to
be placed after the `Include` directive loading the rule with the ID in question. The rule will thus
be disabled during the startup of the server.

The rule IDs can be comma separated, or you can issue a range (e.g. `920000-920999`).

Alternatives exist in the form of `SecRuleRemoveByMsg` and `SecRuleRemoveByTag` which both allow for regular expression patterns.



**Case 2 : Disabling a rule for a specific parameter** </br>

```bash
# ModSecurity Rule Exclusion for cookie PHPSESSID: 942450 SQL Hex Encoding Identified
SecRuleUpdateTargetById 942450 "!REQUEST_COOKIES:PHPSESSID"
```
This is the more advanced form of an exclusion rule that removes an individual parameter from the set of targets of an individual rule.

The directive has to be placed after the `Include` directive loading the rule with the ID in question. The rule target will thus
be disabled during the startup of the server.

The rule IDs can be comma separated, or you can issue a range (e.g., `920000-920999`).

The target can be defined with the help of a regular expression (e.g., `!REQUEST_COOKIES:/^.*SESS/`). 

Alternatives exist in the form of `SecRuleUpdateTargetByMsg` and `SecRuleUpdateTargetByTag` which both allow for regular expression patterns.


**Case 3 : Disabling the rule for a specific path** </br>

```bash
# ModSecurity Rule Exclusion: 920350 Host header is a numeric IP address
SecRule REQUEST_FILENAME "@beginsWith /availability-check.do" \
	"phase:1,nolog,pass,t:none,id:10001,ctl:ruleRemoveById=920350"
```
Location in the configuration: Preferably in front of the *Core Rule Inclusion*, but for *phase:1* can also be placed after *include*. </br>
Phase: Best in phase 1, because the path is known at this moment.</br>


**Case 4 : Disabling rules for specific parameters on a specific path** </br>

```bash
# ModSecurity Rule Exclusion for parameter password: 942450 SQL Hex Encoding Identified
SecRule REQUEST_FILENAME "@beginsWith /login/submit.do" \
	"phase:2,nolog,pass,t:none,id:10002,ctl:ruleRemoveTargetById=942450;ARGS:password"
```
Location in the configuration: Preferably placed after the *Core Rule Inclusion*. </br>
Phase: Required for *post parameter* in phase 2, otherwise conceivable in phase 1.</br>


**Case 5 : Keep the rule enabled, but disable scoring for specific parameters on specific paths** </br>

```bash   
SecRule REQUEST_FILENAME "@beginsWith /app/submit.do" \
	"chain,phase:2,log,pass,t:none,id:10003,msg:'Adjusting inbound anomaly score for rule 950005'"
SecRule "&TX:950005-OWASP_CRS/WEB_ATTACK/FILE_INJECTION-ARGS:contact_form_name" "@ge 1" \
	"setvar:tx.inbound_anomaly_score=-%{tx.critical_anomaly_score}"
```
Location in the configuration: Preferably placed after the *Core Rule Inclusion*. </br>
Phase: Required for *post parameter* in phase 2, otherwise conceivable in phase 1.</br>

In practice, it’s important to proceed systematically. *ModSecurity* and the *core rules* are already complex enough. If we don’t watch out, all of our fine tuning efforts will only result in chaos at the end. It’s better to think about which rule fine tuning approaches you want to work with. In technical terms, the one manipulating the *anomaly scores* is the preferred approach. It is however very hard to read and the work required for writing and testing outweighs the simpler ones, although this in turn is accompanied by the disadvantage described above that all messages for the rule are suppressed.

In the next tutorial we will be turning to practice and deriving fine tuning rules for an untuned application from the log files.

###Step 10 (Goodie): A beer

This tutorial was a hard bit of work. We’ll be taking a break now and treating ourselves to a beer. The next tutorial turns to practice. We have become familiar with the basic techniques, but how exactly do you apply these techniques when you are sinking under a huge number of false positives?

###References
- [OWASP ModSecurity Core Rule Setg](https://coreruleset.org)
- [Spider Labs Blog Post: Exception Handling](http://blog.spiderlabs.com/2011/08/modsecurity-advanced-topic-of-the-week-exception-handling.html)
- [ModSecurity Reference Manual](https://github.com/SpiderLabs/ModSecurity/wiki/Reference-Manual)

### License / Copying / Further use

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
