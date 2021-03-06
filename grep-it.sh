#!/bin/bash
#
# A simple greper for code, loot, IT-tech-stuff-the-customer-throws-at-you.
# Tries to find IT security and privacy related stuff.
# For pentesters.
#
# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <floyd at floyd dot ch> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return
# floyd http://floyd.ch @floyd_ch <floyd at floyd dot ch>
# July 2013
# ----------------------------------------------------------------------------
#
# Requirements:
# - GNU grep. If you have OSX, install from ports or so. Reason: we need regex match -P
# - rm command. Reason: if grep doesn't match anything we remove the corresponding output file
# - mkdir command. Reason: we need to make the $TARGET directory
# - jobs, wait and wc command, if you want to run multiple grep in the background.
#
# Howto:
# - Customize the "OPTIONS" section below to your needs
# - Copy this file to the parent directory which you want to grep
# - run it like this: ./grep-it.sh ./directory-to-grep-through/
#
# Output:
# Default output is optimised to be viewed with "less -R ./grep-output/*" and then you can hop from one file to the next with :n
# and :p. The cat command works fine. If you want another editor you should probably remove --color=always and other grep arguments
# Output files have the following naming conventions (separated by underscore):
# - priority: 1-5, where 1 is more interesting (low false positive rate, certainty of "vulnerability") and 5 is only "you might want to have a look"
# - section: eg. java or php
# - name of what we looked for
#
# Related work:
# - https://www.owasp.org/index.php/Static_Code_Analysis
# - https://samate.nist.gov/index.php/Source_Code_Security_Analyzers.html
# - https://en.wikipedia.org/wiki/List_of_tools_for_static_code_analysis

###
#OPTIONS - please customize
###

#Which grep to use:
#OSX:
GREP_COMMAND="/opt/local/bin/grep"
#Most other *nix
#GREP_COMMAND="grep"
#Do not remove -rP if you don't know what you are doing, otherwise you probably break this script
GREP_ARGUMENTS="-n -A 1 -B 3 -rP"
#my tests with a tool called ripgrep showed there is no real benefit in using it for this script

#Open the colored outputs with "less -R" or cat, otherwise remove --color=always
COLOR_ARGUMENTS="--color=always"
#Output folder if not otherwise specified on the command line
TARGET="./grep-output"
#Write the comment to each file at the beginning
WRITE_COMMENT="true"
#Sometimes we look for composite words with wildcard, eg. root.{0,20}detection, this is the maximum
#of random characters that can be in between. The higher the value the more strings will potentially be flagged.
WILDCARD_SHORT=20
WILDCARD_LONG=200
#Do all greps in background with & while only using MAX_PROCESSES subprocesses
BACKGROUND="false"
MAX_PROCESSES=2 #if you specify the number of cpu cores you have, it should roughly use 100% CPU

#In my opinion I would always leave all the options below here on true,
#because I did find strange android code in iphone apps and vice versa. I would only
#change it if grep needs very long, you are greping a lot of stuff
#or if you have any other performance issues with this script.
DO_JAVA="true"
DO_JSP="true"
DO_SPRING="true"
DO_STRUTS="true"

DO_FLEX="true"

DO_DOTNET="true"

DO_PHP="true"

DO_HTML="true"
DO_JAVASCRIPT="true"
DO_MODSECURITY="true"

DO_MOBILE="true"
DO_ANDROID="true"
DO_IOS="true"

DO_PYTHON="true"
DO_RUBY="true"

#C and derived languages
DO_C="true"

DO_MALWARE_DETECTION="true"

DO_CRYPTO_AND_CREDENTIALS="true"

DO_GENERAL="true"

###
#END OPTIONS
#Normally you don't have to change anything below here...
###

###
#CODE SECTION
#As a user of this script you shouldn't need to care about the stuff that is coming down here...
###

# Conventions if you add new regexes:
# - First think about which sections you want to put a new rule
# - Don't use * in regex but use {0,X} instead. See WILDCARD_ variables for configurable values of X.
# - When using character classes in regexes such as [A-Za-z] and you have to include the dash, make it the last element: [A-Za-z-]
# - make sure functions calls with space before bracket will be found if the language supports it, e.g. "extract (bla)" is allowed in PHP
# - If in doubt, prefer to make two regex and output files rather then joining regexes with |. If one produces false positives it is really annoying to search for the true positives of the other regex.
# - If your regex matches less than 6 characters (eg. "salt"), do not make it case insensitive as this usually produces more fals positives. Rather split into several regexes (eg. one file with case-sensitive matches for "[Ss]alt", one file with case-sensitive matches for "SALT". This way we remove false positives for removesAlternativeName and such). 
# - Run this script with DEBUG_TEST_FLAG="true" to see if everything works fine or if you made copy&paste mistakes etc.
# - Take care with single/double quoted strings. From the bash manual:
# 3.1.2.2 Single Quotes
# Enclosing characters in single quotes (‘'’) preserves the literal value of each character within the quotes. A single quote may not occur between single quotes, even when preceded by a backslash.
# 3.1.2.3 Double Quotes
# Enclosing characters in double quotes (‘"’) preserves the literal value of all characters within the quotes, with the exception of ‘$’, ‘`’, ‘\’, and, when history expansion is enabled, ‘!’. The characters ‘$’ and ‘`’ retain their special meaning within double quotes (see Shell Expansions). The backslash retains its special meaning only when followed by one of the following characters: ‘$’, ‘`’, ‘"’, ‘\’, or newline. Within double quotes, backslashes that are followed by one of these characters are removed. Backslashes preceding characters without a special meaning are left unmodified. A double quote may be quoted within double quotes by preceding it with a backslash. If enabled, history expansion will be performed unless an ‘!’ appearing in double quotes is escaped using a backslash. The backslash preceding the ‘!’ is not removed. The special parameters ‘*’ and ‘@’ have special meaning when in double quotes (see Shell Parameter Expansion).
#
# TODO short term:
# - Nothing :)
#
# TODO longterm (aka "probably never but I know I should"):
# - Improve comments everywhere
# - Add comments about case-sensitivity and whitespace behavior of languages and other syntax rules that might influence our regexes
# - Duplicate a couple of regexes to ones that *only* have true positives usually (or at least a lot less false positives)
# - Have a look at/implement&reference rules:
#  - Files starting with mod* at https://github.com/nccgroup/VCG/tree/master/VisualCodeGrepper 
#  - http://findbugs.sourceforge.net/bugDescriptions.html
#  - https://www.bishopfox.com/resources/downloads/
#  - https://pmd.github.io/
#  - https://msdn.microsoft.com/en-us/library/aa449703.aspx
#  - http://www.splint.org/

#When the following flag is enable the tool switches to testing mode and won't do the actual work
DEBUG_TEST_FLAG="false"
#A helper var for debugging purposes
DEBUG_TMP_OUTFILE_NAMES=""

if [ $# -lt 1 ]
then
  echo "Usage: $(basename $0) directory-to-grep-through"
  exit 0
fi

if [ "$1" = "." ]
then
  echo "You are shooting yourself in the foot. Do not grep through . but rather cd into parent directory and mv $(basename $0) there."
  echo "READ THE HOWTO (3 lines)"
  exit 0
fi

if [ $# -eq 2 ]
then
  #argument without last /
  TARGET=${2%/}
fi

if [ ! -f "$GREP_COMMAND" ]
then
    echo "WARNING: It seems your specified grep in $GREP_COMMAND does not exist, falling back to just 'grep'"
    GREP_COMMAND="grep"
fi

STANDARD_GREP_ARGUMENTS="$GREP_ARGUMENTS $COLOR_ARGUMENTS"

#argument without last /
SEARCH_FOLDER=${1%/}

mkdir "$TARGET"

if [ "$DEBUG_TEST_FLAG" = "true" ]; then
    echo "WE ARE RUNNING IN TEST MODE. NOT DOING THE ACTUAL WORK, JUST VERIFYING THIS SCRIPT IS DOING WHAT IT SHOULD."
    echo "If you want to run in normal mode, set DEBUG_TEST_FLAG to false"
fi
echo "Your standard grep arguments (customize in OPTIONS section of this script): $STANDARD_GREP_ARGUMENTS"
echo "Output will be put into this folder: $TARGET"
echo "You are currently greping through folder: $SEARCH_FOLDER"
sleep 2

function search()
{
    
    if [ "$DEBUG_TEST_FLAG" = "true" ]; then
        test_run "$@"
    else
        #Decide if doing in background or not
        if [ "$BACKGROUND" = "true" ]; then
            #make sure we don't fork-bomb, so run at max $MAX_PROCESSES at once
            while true ; do
                jobcnt=$(jobs -p|wc -l)
                #echo "jobcnt: $jobcnt"
                if [ $jobcnt -lt $MAX_PROCESSES ] ; then
                    actual_search "$@" &
                    break
                else
                    sleep 0.25
                fi
            done
        else
            actual_search "$@"
        fi
    fi

}

function actual_search()
{
    COMMENT="$1"
    EXAMPLE="$2"
    FALSE_POSITIVES_EXAMPLE="$3"
    SEARCH_REGEX="$4"
    OUTFILE="$5"
    ARGS_FOR_GREP="$6" #usually just -i for case insensitive or empty, very rare we use -o for match-only part with no context info
    #echo "$COMMENT, $SEARCH_REGEX, $OUTFILE, $ARGS_FOR_GREP, $WRITE_COMMENT, $BACKGROUND, $GREP_COMMAND, $STANDARD_GREP_ARGUMENTS, $TARGET"
    echo "Searching (args for grep:$ARGS_FOR_GREP) for $SEARCH_REGEX --> writing to $OUTFILE"
    if [ "$WRITE_COMMENT" = "true" ]; then
        echo "# Info: $COMMENT" >> "$TARGET/$OUTFILE"
        echo "# Filename $OUTFILE" >> "$TARGET/$OUTFILE"
        echo "# Example: $EXAMPLE" >> "$TARGET/$OUTFILE"
        echo "# False positive example: $FALSE_POSITIVES_EXAMPLE" >> "$TARGET/$OUTFILE"
        echo "# Grep args: $ARGS_FOR_GREP" >> "$TARGET/$OUTFILE"
        echo "# Search regex: $SEARCH_REGEX" >> "$TARGET/$OUTFILE"
    fi
    $GREP_COMMAND $ARGS_FOR_GREP $STANDARD_GREP_ARGUMENTS "$SEARCH_REGEX" "$SEARCH_FOLDER" >> "$TARGET/$OUTFILE"
    if [ $? -ne 0 ]; then
        #echo "Last grep didn't have a result, removing $OUTFILE"
        rm "$TARGET/$OUTFILE"
    fi
}

function test_run()
{
    COMMENT="$1"
    EXAMPLE="$2"
    FALSE_POSITIVES_EXAMPLE="$3"
    SEARCH_REGEX="$4"
    OUTFILE="$5"
    ARGS_FOR_GREP="$6"
    #echo "Testing: $COMMENT, $SEARCH_REGEX, $OUTFILE, $ARGS_FOR_GREP, $WRITE_COMMENT, $BACKGROUND, $GREP_COMMAND, $STANDARD_GREP_ARGUMENTS, $TARGET"
    #First, test that regexes match the example
    echo "$EXAMPLE" > "testing/temp_file.txt"
    $GREP_COMMAND $ARGS_FOR_GREP $STANDARD_GREP_ARGUMENTS "$SEARCH_REGEX" "testing/temp_file.txt" > /dev/null
    if [ $? -ne 0 ]; then
        echo "FAIL! $EXAMPLE was not matched for regex $SEARCH_REGEX"
        echo "Test file content:"
        cat testing/temp_file.txt
    #else
        #echo "PASS! $SEARCH_REGEX"
    fi
    #Second, check that the OUTFILE name is unique
    echo $DEBUG_TMP_OUTFILE_NAMES|$GREP_COMMAND -q $OUTFILE
    if [ $? -eq 0 ]; then
        echo "FAIL! $OUTFILE is specified twice in the script!"
    fi
    DEBUG_TMP_OUTFILE_NAMES="$DEBUG_TMP_OUTFILE_NAMES $OUTFILE"
    #Third, check if comment empty
    if [ "$COMMENT" = "" ]; then
        echo "FAIL! $OUTFILE has no comment section!"
    fi
    #Four, check if example empty
    if [ "$EXAMPLE" = "" ]; then
        echo "FAIL! $OUTFILE has no example section!"
    fi
    
}

#The Java stuff
if [ "$DO_JAVA" = "true" ]; then
    
    echo "#Doing Java"
    
    search "All Strings between double quotes. Like the command line tool 'strings' for Java code." \
    'String bla = "This is a Java String";' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '"[^"]{4,500}"' \
    "5_java_strings.txt" \
    "-o" #Special case, we only want to show the strings themselves, therefore -o to output the match only
    
    search "All javax.crypto usage" \
    'import javax.crypto.bla;' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'javax.crypto' \
    "4_java_crypto_javax-crypto.txt"
    
    search "Bouncycastle is a common Java crypto provider" \
    'import org.bouncycastle.bla;' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "bouncy.{0,$WILDCARD_SHORT}castle" \
    "4_java_crypto_bouncycastle.txt" \
    "-i"
    
    search "SecretKeySpec is used to initialize a new encryption key: instance of SecretKey, often passed in the first argument as a byte[], which is the actual key" \
    'new SecretKeySpec(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'new\sSecretKeySpec\(' \
    "1_java_crypto_new-SecretKeySpec.txt" \
    "-i"
    
    search "PBEKeySpec( is used to initialize a new encryption key: instance of PBEKeySpec, often passed in the first argument as a byte[], which is the actual key" \
    'new PBEKeySpec(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'new\sPBEKeySpec\(' \
    "1_java_crypto_new-PBEKeySpec.txt" \
    "-i"
    
    search "GenerateKey is another form of making a new instance of SecretKey, depending on the use case randomly generates one on the fly. It's interesting to see where the key goes next, where it's stored or accidentially written to a log file." \
    '.generateKey()' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.generateKey\(' \
    "2_java_crypto_generateKey.txt"
    
    search "Occurences of KeyGenerator.getInstance(ALGORITHM) it's interesting to see where the key goes next, where it's stored or accidentially written to a log file. Make sure the cipher is secure." \
    'KeyGenerator.getInstance(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'KeyGenerator\.getInstance\(' \
    "2_java_crypto_keygenerator-getinstance.txt"
    
    search "Occurences of Cipher.getInstance(ALGORITHM) it's interesting to see where the key goes next, where it's stored or accidentially written to a log file. Make sure the cipher is secure." \
    'Cipher.getInstance("RSA/NONE/NoPadding");' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Cipher\.getInstance\(' \
    "2_java_crypto_cipher_getInstance.txt"
    
    search "The Random class shouldn't be used for crypthography in Java, the SecureRandom should be used instead." \
    'Random random = new Random();' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'new Random\(' \
    "2_java_crypto_random.txt"
    
    search "The Math.random class shouldn't be used for crypthography in Java, the SecureRandom should be used instead." \
    'Math.random();' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Math.random\(' \
    "2_java_math_random.txt"
    
    search "Message digest is used to generate hashes" \
    'messagedigest' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'messagedigest' \
    "2_java_crypto_messagedigest.txt" \
    "-i"
    
    search "KeyPairGenerator, well, to generate key pairs, see http://docs.oracle.com/javase/7/docs/api/java/security/KeyPairGenerator.html . It's interesting to see where the key goes next, where it's stored or accidentially written to a log file." \
    'KeyPairGenerator(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'KeyPairGenerator\(' \
    "1_java_crypto_keypairgenerator.txt"
    
    search "String comparisons have to be done with .equals() in Java, not with == (won't work). Attention: False positives often occur if you used a decompiler to get the Java code, additionally it's allowed in JavaScript." \
    '    toString(  )    ==' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "toString\(\s{0,$WILDCARD_SHORT}\)\s{0,$WILDCARD_SHORT}==" \
    "4_java_string_comparison1.txt"
    
    search "String comparisons have to be done with .equals() in Java, not with == (won't work). Attention: False positives often occur if you used a decompiler to get the Java code, additionally it's allowed in JavaScript." \
    ' ==     toString() ' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "==\s{0,$WILDCARD_SHORT}toString\(\s{0,$WILDCARD_SHORT}\)" \
    "4_java_string_comparison2.txt"
    
    search "String comparisons have to be done with .equals() in Java, not with == (won't work). Attention: False positives often occur if you used a decompiler to get the Java code, additionally it's allowed in JavaScript." \
    ' ==     "' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "==\s{0,$WILDCARD_SHORT}\"" \
    "4_java_string_comparison3.txt"
    
    search "Problem with equals and equalsIgnoreCase for checking user supplied passwords or Hashes or HMACs or XYZ is that it is not a time-consistent method, therefore allowing timing attacks." \
    '.equals(hash_from_request)' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "equals\(.{0,$WILDCARD_SHORT}[Hh][Aa][Ss][Hh]" \
    "2_java_string_comparison_equals_hash.txt"
    
    search "Problem with equals and equalsIgnoreCase for checking user supplied passwords or Hashes or HMACs or XYZ is that it is not a time-consistent method, therefore allowing timing attacks." \
    '.equalsIgnoreCase(hash_from_request' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "equalsIgnoreCase\(.{0,$WILDCARD_SHORT}[Hh][Aa][Ss][Hh]" \
    "2_java_string_comparison_equalsIgnoreCase_hash.txt"
    
    search "String comparisons: Filters and conditional decisions on user input should better be done with .equalsIgnoreCase() in Java in most cases, so that the clause doesn't miss something (e.g. think about string comparison in filters) or long switch case. Another problem with equals and equalsIgnoreCase for checking user supplied passwords or Hashes or HMACs or XYZ is that it is not a time-consistent method, therefore allowing timing attacks." \
    '.equals(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'equals\(' \
    "4_java_string_comparison_equals.txt"
    
    search "String comparisons: Filters and conditional decisions on user input should better be done with .equalsIgnoreCase() in Java in most cases, so that the clause doesn't miss something (e.g. think about string comparison in filters) or long switch case. Another problem with equals and equalsIgnoreCase for checking user supplied passwords or Hashes or HMACs or XYZ is that it is not a time-consistent method, therefore allowing timing attacks." \
    '.equalsIgnoreCase(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'equalsIgnoreCase\(' \
    "4_java_string_comparison_equalsIgnoreCase.txt"
    
    search "The syntax for SQL executions start with execute and this should as well catch generic execute calls." \
    'executeBlaBla(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "execute.{0,$WILDCARD_SHORT}\(" \
    "3_java_sql_execute.txt"
    
    search "SQL syntax" \
    'addBatch(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "addBatch\(" \
    "3_java_sql_addBatch.txt"
    
    search "SQL prepared statements, can go wrong if you prepare after you use user supplied input in the query syntax..." \
    'prepareStatement(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "prepareStatement\(" \
    "2_java_sql_prepareStatement.txt"
    
    search "Method to set HTTP headers in Java" \
    '.setHeader(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.setHeader\(" \
    "3_java_http_setHeader.txt"
    
    search "Method to set HTTP headers in Java" \
    '.addCookie(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.addCookie\(" \
    "3_java_http_addCookie.txt"
        
    search "Method to send HTTP redirect in Java" \
    '.sendRedirect(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.sendRedirect\(" \
    "3_java_http_sendRedirect.txt"
    
    search "Java add HTTP header" \
    '.addHeader(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.addHeader\(" \
    "3_java_http_addHeader.txt"
    
    search "Java get HTTP header" \
    '.getHeaders(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.getHeaders\(" \
    "3_java_http_getHeaders.txt"
    
    search "Java get HTTP cookies" \
    '.getCookies(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.getCookies\(" \
    "3_java_http_getCookies.txt"
    
    search "Java get remote host" \
    '.getRemoteHost(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.getRemoteHost\(" \
    "3_java_http_getRemoteHost.txt"
    
    search "Java get remote user" \
    '.getRemoteUser(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.getRemoteUser\(" \
    "3_java_http_getRemoteUser.txt"
    
    search "Java is secure" \
    '.isSecure(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.isSecure\(" \
    "3_java_http_isSecure.txt"
    
    search "Java get requested session ID" \
    '.getRequestedSessionId(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.getRequestedSessionId\(" \
    "3_java_http_getRequestedSessionId.txt"
    
        
    search "Java get content type" \
    '.getContentType(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.getContentType\(" \
    "3_java_http_getContentType.txt"
    
    search "Java HTTP or XML local name" \
    '.getLocalName(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.getLocalName\(" \
    "3_java_http_getLocalName.txt"
    
    search "Java generic parameter fetching" \
    '.getParameterBlabla(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.getParameter.{0,$WILDCARD_SHORT}\(" \
    "3_java_http_getParameter.txt"
    
    search "Potential tainted input in string format." \
    'String.format("bla-%s"+taintedInput, variable);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "String\.format\(\s{0,$WILDCARD_SHORT}\"[^\"]{1,$WILDCARD_LONG}\"\s{0,$WILDCARD_SHORT}\+" \
    "3_java_format_string1.txt"
    
    search "Potential tainted input in string format." \
    'String.format(variable)' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "String\.format\(\s{0,$WILDCARD_SHORT}[^\"]" \
    "3_java_format_string2.txt"
    
    search "Java ProcessBuilder" \
    'ProcessBuilder' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'ProcessBuilder' \
    "2_java_ProcessBuilder.txt" \
    "-i"
    
    search "HTTP session timeout" \
    'setMaxInactiveInterval()' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'setMaxInactiveInterval\(' \
    "3_java_servlet_setMaxInactiveInterval.txt"
    
    #Take care with the following regex, @ has a special meaning in double quoted strings, but not in single quoted strings
    search "Find out which Java Beans get persisted with javax.persistence" \
    '@Entity' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '@Entity|@ManyToOne|@OneToMany|@OneToOne|@Table|@Column' \
    "3_java_persistent_beans.txt" \
    "-l" #Special case, we only want to know matching files to know which beans get persisted, therefore -l to output matching files
    
    #Take care with the following regex, @ has a special meaning in double quoted strings, but not in single quoted strings
    search "The source code shows the database table/column names... e.g. if you find a sql injection later on, this will help for the exploitation" \
    '@Column(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '@Column\(' \
    "3_java_persistent_columns_in_database.txt"
    
    #Take care with the following regex, @ has a special meaning in double quoted strings, but not in single quoted strings
    search "The source code shows the database table/column names... e.g. if you find a sql injection later on, this will help for the exploitation" \
    '@Table(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '@Table\(' \
    "3_java_persistent_tables_in_database.txt"
    
    search "Find out which Java classes do any kind of io" \
    'java.net.' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'java\.net\.' \
    "4_java_io_java_net.txt" \
    "-l" #Special case, we only want to know matching files to know which beans get persisted, therefore -l to output matching files
    
    search "Find out which Java classes do any kind of io" \
    'java.io.' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'java\.io\.' \
    "4_java_io_java_io.txt" \
    "-l" #Special case, we only want to know matching files to know which beans get persisted, therefore -l to output matching files
    
    search "Find out which Java classes do any kind of io" \
    'javax.servlet' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'javax\.servlet' \
    "4_java_io_javax_servlet.txt" \
    "-l" #Special case, we only want to know matching files to know which beans get persisted, therefore -l to output matching files
    
    search "Find out which Java classes do any kind of io" \
    'org.apache.http' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'org\.apache\.http' \
    "4_java_io_apache_http.txt" \
    "-l" #Special case, we only want to know matching files to know which beans get persisted, therefore -l to output matching files
    
    search "Especially for high security applications. From http://docs.oracle.com/javase/1.5.0/docs/guide/security/jce/JCERefGuide.html#PBEEx : \"It would seem logical to collect and store the password in an object of type java.lang.String. However, here's the caveat: Objects of type String are immutable, i.e., there are no methods defined that allow you to change (overwrite) or zero out the contents of a String after usage. This feature makes String objects unsuitable for storing security sensitive information such as user passwords. You should always collect and store security sensitive information in a char array instead.\" " \
    'String password' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "string .{0,$WILDCARD_SHORT}password" \
    "4_java_confidential_data_in_strings_password.txt" \
    "-i"
    
    search "Especially for high security applications. From http://docs.oracle.com/javase/1.5.0/docs/guide/security/jce/JCERefGuide.html#PBEEx : \"It would seem logical to collect and store the password in an object of type java.lang.String. However, here's the caveat: Objects of type String are immutable, i.e., there are no methods defined that allow you to change (overwrite) or zero out the contents of a String after usage. This feature makes String objects unsuitable for storing security sensitive information such as user passwords. You should always collect and store security sensitive information in a char array instead.\" " \
    'String secret' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "string .{0,$WILDCARD_SHORT}secret" \
    "4_java_confidential_data_in_strings_secret.txt" \
    "-i"
    
    search "Especially for high security applications. From http://docs.oracle.com/javase/1.5.0/docs/guide/security/jce/JCERefGuide.html#PBEEx : \"It would seem logical to collect and store the password in an object of type java.lang.String. However, here's the caveat: Objects of type String are immutable, i.e., there are no methods defined that allow you to change (overwrite) or zero out the contents of a String after usage. This feature makes String objects unsuitable for storing security sensitive information such as user passwords. You should always collect and store security sensitive information in a char array instead.\" " \
    'String key' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "string .{0,$WILDCARD_SHORT}key" \
    "4_java_confidential_data_in_strings_key.txt" \
    "-i"
    
    search "Especially for high security applications. From http://docs.oracle.com/javase/1.5.0/docs/guide/security/jce/JCERefGuide.html#PBEEx : \"It would seem logical to collect and store the password in an object of type java.lang.String. However, here's the caveat: Objects of type String are immutable, i.e., there are no methods defined that allow you to change (overwrite) or zero out the contents of a String after usage. This feature makes String objects unsuitable for storing security sensitive information such as user passwords. You should always collect and store security sensitive information in a char array instead.\" " \
    'String cvv' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "string .{0,$WILDCARD_SHORT}cvv" \
    "4_java_confidential_data_in_strings_cvv.txt" \
    "-i"
    
    search "Especially for high security applications. From http://docs.oracle.com/javase/1.5.0/docs/guide/security/jce/JCERefGuide.html#PBEEx : \"It would seem logical to collect and store the password in an object of type java.lang.String. However, here's the caveat: Objects of type String are immutable, i.e., there are no methods defined that allow you to change (overwrite) or zero out the contents of a String after usage. This feature makes String objects unsuitable for storing security sensitive information such as user passwords. You should always collect and store security sensitive information in a char array instead.\" " \
    'String user' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "string .{0,$WILDCARD_SHORT}user" \
    "4_java_confidential_data_in_strings_user.txt" \
    "-i"
    
    search "Especially for high security applications. From http://docs.oracle.com/javase/1.5.0/docs/guide/security/jce/JCERefGuide.html#PBEEx : \"It would seem logical to collect and store the password in an object of type java.lang.String. However, here's the caveat: Objects of type String are immutable, i.e., there are no methods defined that allow you to change (overwrite) or zero out the contents of a String after usage. This feature makes String objects unsuitable for storing security sensitive information such as user passwords. You should always collect and store security sensitive information in a char array instead.\" " \
    'String passcode' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "string .{0,$WILDCARD_SHORT}passcode" \
    "4_java_confidential_data_in_strings_passcode.txt" \
    "-i"
    
    search "Especially for high security applications. From http://docs.oracle.com/javase/1.5.0/docs/guide/security/jce/JCERefGuide.html#PBEEx : \"It would seem logical to collect and store the password in an object of type java.lang.String. However, here's the caveat: Objects of type String are immutable, i.e., there are no methods defined that allow you to change (overwrite) or zero out the contents of a String after usage. This feature makes String objects unsuitable for storing security sensitive information such as user passwords. You should always collect and store security sensitive information in a char array instead.\" " \
    'String passphrase' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "string .{0,$WILDCARD_SHORT}passphrase" \
    "4_java_confidential_data_in_strings_passphrase.txt" \
    "-i"
    
    search "Especially for high security applications. From http://docs.oracle.com/javase/1.5.0/docs/guide/security/jce/JCERefGuide.html#PBEEx : \"It would seem logical to collect and store the password in an object of type java.lang.String. However, here's the caveat: Objects of type String are immutable, i.e., there are no methods defined that allow you to change (overwrite) or zero out the contents of a String after usage. This feature makes String objects unsuitable for storing security sensitive information such as user passwords. You should always collect and store security sensitive information in a char array instead.\" " \
    'String pin' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "string .{0,$WILDCARD_SHORT}pin" \
    "4_java_confidential_data_in_strings_pin.txt" \
    "-i"
    
    search "Especially for high security applications. From http://docs.oracle.com/javase/1.5.0/docs/guide/security/jce/JCERefGuide.html#PBEEx : \"It would seem logical to collect and store the password in an object of type java.lang.String. However, here's the caveat: Objects of type String are immutable, i.e., there are no methods defined that allow you to change (overwrite) or zero out the contents of a String after usage. This feature makes String objects unsuitable for storing security sensitive information such as user passwords. You should always collect and store security sensitive information in a char array instead.\" " \
    'String creditcard_number' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "string .{0,$WILDCARD_SHORT}credit" \
    "4_java_confidential_data_in_strings_credit.txt" \
    "-i"
    
    search "Attention: SSLSocketFactory means in general you will skip SSL hostname verification because the SSLSocketFactory can't know which protocol (HTTP/LDAP/etc.) and therefore can't lookup the hostname. Even Apache's HttpClient version 3 for Java is broken: see https://crypto.stanford.edu/~dabo/pubs/abstracts/ssl-client-bugs.html" \
    'SSLSocketFactory' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'SSLSocketFactory' \
    "3_java_SSLSocketFactory.txt"
    
    search "It's very easy to construct a backdoor in Java with Unicode \u characters, even within multi line comments, see http://pastebin.com/iGQhuUGd and https://plus.google.com/111673599544007386234/posts/ZeXvRCRZ3LF ." \
    '\u0041\u0042' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\\u00..\\u00..' \
    "3_java_backdoor_as_unicode.txt" \
    "-i"
    
    search "CheckValidity method of X509Certificate in Java is a very confusing naming for developers new to SSL/TLS and has been used as the *only* check to see if a certificate is valid or not in the past. This method *only* checks the date-validity, see http://docs.oracle.com/javase/7/docs/api/java/security/cert/X509Certificate.html#checkValidity%28%29 : 'Checks that the certificate is currently valid. It is if the current date and time are within the validity period given in the certificate.'" \
    'paramArrayOfX509Certificate[0].checkValidity(); return;' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.checkValidity\(" \
    "2_java_ssl_checkValidity.txt"
    
    search "CheckServerTrusted, often used for certificate pinning on Java and Android, however, this is very very often insecure and not effective, see https://www.cigital.com/blog/ineffective-certificate-pinning-implementations/ . The correct method is to replace the system's TrustStore." \
    'checkServerTrusted(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "checkServerTrusted\(" \
    "2_java_checkServerTrusted.txt"
    
    search "getPeerCertificates, often used for certificate pinning on Java and Android, however, this is very very often insecure and not effective, see https://www.cigital.com/blog/ineffective-certificate-pinning-implementations/ . The correct method is to replace the system's TrustStore." \
    'getPeerCertificates(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "getPeerCertificates\(" \
    "2_java_getPeerCertificates.txt"
    
    search "getPeerCertificateChain, often used for certificate pinning on Java and Android, however, this is very very often insecure and not effective, see https://www.cigital.com/blog/ineffective-certificate-pinning-implementations/ . The correct method is to replace the system's TrustStore." \
    'getPeerCertificateChain(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "getPeerCertificateChain\(" \
    "2_java_getPeerCertificateChain.txt"
    
    search "A simple search for getRuntime(), which is often used later on for .exec()" \
    'getRuntime()' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'getRuntime\(' \
    "3_java_getruntime.txt"
    
    search "A simple search for getRuntime().exec()" \
    'getRuntime().exec()' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'getRuntime\(\)\.exec\(' \
    "2_java_runtime_exec_1.txt"
    
    search "A search for Process p = r.exec()" \
    'Process p = r.exec(args1);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "Process.{0,$WILDCARD_SHORT}\.exec\(" \
    "2_java_runtime_exec_2.txt"
    
    search "The function openProcess is included in apache commons and does a getRuntime().exec" \
    'p = openProcess(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "openProcess\(" \
    "2_java_apache_common_openProcess.txt"
    
    search "Validation in Java can be done via javax.validation. " \
    'import javax.validation.bla;' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "javax.validation" \
    "2_java_javax-validation.txt"
    
    #Take care with the following regex, @ has a special meaning in double quoted strings, but not in single quoted strings
    search 'Validation in Java can be done via certain @constraint' \
    '@constraint' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '@constraint' \
    "2_java_constraint_annotation.txt"
    
    #Take care with the following regex, @ has a special meaning in double quoted strings, but not in single quoted strings
    search 'Lint will sometimes complain about security related stuff, this annotation deactivates the warning' \
    '@SuppressLint' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '@SuppressLint' \
    "2_java_suppresslint.txt"
    
    search 'Deserialization is something that can result in remote command execution, there are various exploits for such things, see http://foxglovesecurity.com/2015/11/06/what-do-weblogic-websphere-jboss-jenkins-opennms-and-your-application-have-in-common-this-vulnerability/ for example' \
    'new ObjectOutputStream(abc);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'new ObjectOutputStream' \
    "2_java_serialization-objectOutputStream.txt"
    
    search 'Deserialization is something that can result in remote command execution, there are various exploits for such things, see http://foxglovesecurity.com/2015/11/06/what-do-weblogic-websphere-jboss-jenkins-opennms-and-your-application-have-in-common-this-vulnerability/ for example' \
    'abc.writeObject(def);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.writeObject\(' \
    "2_java_serialization-writeObject.txt"
    
    search 'Deserialization is something that can result in remote command execution, there are various exploits for such things, see http://foxglovesecurity.com/2015/11/06/what-do-weblogic-websphere-jboss-jenkins-opennms-and-your-application-have-in-common-this-vulnerability/ for example' \
    'abc.readObject(def);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.readObject\(' \
    "1_java_serialization-readObject.txt"
    
    search 'Java serialized data? Usually Java serialized data in base64 format starts with rO0 or non-base64 with hex ACED0005. Deserialization is something that can result in remote command execution, there are various exploits for such things, see http://foxglovesecurity.com/2015/11/06/what-do-weblogic-websphere-jboss-jenkins-opennms-and-your-application-have-in-common-this-vulnerability/ for example' \
    'rO0ABXNyABpodWRzb24ucmVtb3RpbmcuQ2FwYWJpbGl0eQAAAAAAAAABAgABSgAEbWFza3hwAAAAAAAAAJP4=' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'rO0' \
    "2_java_serialization-base64serialized-data.txt"
    
    search 'Java serialized data? Usually Java serialized data in base64 format starts with rO0 or non-base64 with hex ACED0005. Deserialization is something that can result in remote command execution, there are various exploits for such things, see http://foxglovesecurity.com/2015/11/06/what-do-weblogic-websphere-jboss-jenkins-opennms-and-your-application-have-in-common-this-vulnerability/ for example' \
    'ACED0005' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'AC ?ED ?00 ?05' \
    "2_java_serialization-hexserialized-data.txt" \
    "-i"
    
    search 'Java serialized data? Usually Java serialized data in base64 format starts with rO0 or non-base64 with hex ACED0005. Decidezation is something that can result in remote command execution, there are various exploits for such things, see http://foxglovesecurity.com/2015/11/06/what-do-weblogic-websphere-jboss-jenkins-opennms-and-your-application-have-in-common-this-vulnerability/ for example' \
    '\xAC\xED\x00\x05' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\\xAC\\xED\\x00\\x05' \
    "2_java_serialization-serialized-data.txt"
    
    search 'JMXInvokerServlet is a JBoss interface that is usually vulnerable to Java deserialization attacks. There are various exploits for such things, see http://foxglovesecurity.com/2015/11/06/what-do-weblogic-websphere-jboss-jenkins-opennms-and-your-application-have-in-common-this-vulnerability/ for example' \
    'JMXInvokerServlet' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'JMXInvokerServlet' \
    "2_java_serialization-JMXInvokerServlet.txt"
    
    search 'InvokerTransformer is a vulnerable commons collection class that can be exploited if the web application has a Java object deserialization interface/issue, see http://foxglovesecurity.com/2015/11/06/what-do-weblogic-websphere-jboss-jenkins-opennms-and-your-application-have-in-common-this-vulnerability/ for example' \
    'InvokerTransformer' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'InvokerTransformer' \
    "2_java_serialization-invokertransformer.txt"
    
    search 'File.createTempFile is prone to race condition under certain circumstances, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=java' \
    'File.createTempFile();' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.createTempFile\(' \
    "3_java_createTempFile.txt"
    
    search 'HttpServletRequest.getRequestedSessionId returns the session ID requested by the client in the HTTP cookie header, not the one set by the server, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=java' \
    'HttpServletRequest.getRequestedSessionId();' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.getRequestedSessionId\(' \
    "3_java_getRequestedSessionId.txt"
    
    search 'NullCipher is obviously a cipher that is not secure, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=java' \
    'new NullCipher();' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'NullCipher' \
    "3_java_NullCipher.txt"
    
    search 'Dynamic class loading?, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=java' \
    'Class c = Class.forName(cn);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Class\.forName' \
    "3_java_class_forName.txt"
    
    search 'New cookie should automatically be followed by c.setSecure(true); to make sure the secure flag ist set, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=java' \
    'Cookie c = new Cookie(a, b);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'new\sCookie\(' \
    "3_java_new_cookie.txt"
    
    search 'Servlet methods that throw exceptions might reveal sensitive information, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=java' \
    'public void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException, ServletException' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "void do.{0,$WILDCARD_LONG}throws.{0,$WILDCARD_LONG}ServletException" \
    "3_java_servlet_exception.txt"
    
    search 'Security decisions should not be done based on the HTTP referer header as it is attacker chosen, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=java' \
    'String referer = request.getHeader("referer");' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.getHeader\("referer' \
    "3_java_getHeader_referer.txt"
    
    search 'Usually it is a bad idea to subclass cryptographic implementation, developers might break the implementation, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=java' \
    'MyCryptographicAlgorithm extends MessageDigest {' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "extends.{0,$WILDCARD_LONG}MessageDigest" \
    "3_java_extends_MessageDigest.txt"
    
    search 'Usually it is a bad idea to subclass cryptographic implementation, developers might break the implementation, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=java' \
    'MyCryptographicAlgorithm extends WhateverCipher {' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "extends.{0,$WILDCARD_LONG}cipher" \
    "3_java_extends_cipher.txt" \
    "-i"
    
    search "printStackTrace logs and should not be in production (also logs to Android log), information leakage, etc." \
    '.printStackTrace()' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.printStackTrace\(' \
    "3_java_printStackTrace.txt"
    
    search "setAttribute is usually used to set an attribute of a session object, untrusted data should not be added to a session object" \
    'session.setAttribute("abc", untrusted_input);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.setAttribute\(' \
    "3_java_setAttribute.txt"
    
    search "StreamTokenizer, look for parsing errors, see https://docs.oracle.com/javase/7/docs/api/java/io/StreamTokenizer.html" \
    'StreamTokenizer' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'StreamTokenizer' \
    "3_java_StreamTokenizer.txt"
    
    search "getResourceAsStream, see http://docs.oracle.com/javase/7/docs/api/java/lang/Class.html#getResourceAsStream(java.lang.String)" \
    'getResourceAsStream' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'getResourceAsStream' \
    "3_java_getResourceAsStream.txt"
    
    
fi

#The JSP specific stuff
if [ "$DO_JSP" = "true" ]; then
    
    echo "#Doing JSP"
    
    search "JSP redirect" \
    '.sendRedirect(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.sendRedirect\(' \
    "2_java_jsp_redirect.txt"
    
    search "JSP redirect" \
    '.forward(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.forward\(' \
    "2_java_jsp_forward_1.txt"
    
    search "JSP redirect" \
    ':forward' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    ':forward' \
    "2_java_jsp_forward_2.txt"
    
    search "Can introduce XSS" \
    'escape=false' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "escape\s{0,$WILDCARD_SHORT}=\s{0,$WILDCARD_SHORT}'?\"?\s{0,$WILDCARD_SHORT}false" \
    "1_java_jsp_xss_escape.txt" \
    "-i"
    
    search "Can introduce XSS" \
    'escapeXml=false' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "escapeXml\s{0,$WILDCARD_SHORT}=\s{0,$WILDCARD_SHORT}'?\"?\s{0,$WILDCARD_SHORT}false" \
    "1_java_jsp_xss_escapexml.txt" \
    "-i"
    
    search "Can introduce XSS when simply writing a bean property to HTML without escaping. Attention: there are now client-side JavaScript libraries using the same tags for templates!" \
    '<%=bean.getName()%>' \
    'Attention: there are now client-side JavaScript libraries using the same tags for templates!' \
    "<%=\s{0,$WILDCARD_SHORT}[A-Za-z0-9_]{1,$WILDCARD_LONG}.get[A-Za-z0-9_]{1,$WILDCARD_LONG}\(" \
    "1_java_jsp_property_to_html_xss.txt" \
    "-i"
    
    search "Java generic JSP parameter get" \
    '.getParameter(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.getParameter\(" \
    "3_java_jsp_property_to_html_xss.txt" \
    "-i"
    
    search "Can introduce XSS when simply writing a bean property to HTML without escaping." \
    'out.print("<option "+bean.getName()+"=jjjj");' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "out.printl?n?\(\"<.{1,$WILDCARD_LONG}\+.{1,$WILDCARD_LONG}\);" \
    "1_java_jsp_out_print_to_html_xss2.txt" \
    "-i"
    
    search "JSP file upload" \
    '<s:file test' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "<s:file\s" \
    "1_java_jsp_file_upload.txt" \
    "-i"
fi

#The Java Spring specific stuff
if [ "$DO_SPRING" = "true" ]; then
    
    echo "#Doing Java Spring"
    
    search "DataBinder.setAllowedFields. See e.g. http://blog.fortify.com/blog/2012/03/23/Mass-Assignment-Its-Not-Just-For-Rails-Anymore ." \
    'DataBinder.setAllowedFields' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'DataBinder\.setAllowedFields' \
    "2_java_spring_mass_assignment.txt" \
    "-i"
    
    search "stripUnsafeHTML, method of the Spring Surf Framework can introduce thinks like XSS, because it is not really protecting." \
    'stripUnsafeHTML' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'stripUnsafeHTML' \
    "2_java_spring_stripUnsafeHTML.txt" \
    "-i"
    
    search "stripEncodeUnsafeHTML, method of the Spring Surf Framework can introduce thinks like XSS, because it is not really protecting." \
    'stripEncodeUnsafeHTML' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'stripEncodeUnsafeHTML' \
    "2_java_spring_stripEncodeUnsafeHTML.txt" \
    "-i"
    
    search "RequestMapping method of the Spring Surf Framework to see how request URLs are mapped to classes." \
    '@RequestMapping(method=RequestMethod.GET, value={"/user","/user/{id}"})' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '@RequestMapping\(' \
    "3_java_spring_requestMapping.txt"
    
    search "ServletMapping XML of the Spring Surf Framework to see how request URLs are mapped to classes." \
    '<servlet-mapping><servlet-name>spring</servlet-name><url-pattern>*.html</url-pattern><url-pattern>/gallery/*</url-pattern><url-pattern>/galleryupload/*</url-pattern>' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '<servlet-mapping>' \
    "3_java_spring_servletMapping.txt"
    
    
fi

#The Java Struts specific stuff
if [ "$DO_STRUTS" = "true" ]; then
    
    echo "#Doing Java Struts"
    
    search "Action mappings for struts where the validation is disabled" \
    'validate  =  "false' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "validate\s{0,$WILDCARD_SHORT}=\s{0,$WILDCARD_SHORT}'?\"?false" \
    "1_java_struts_deactivated_validation.txt" \
    "-i"
    
    search "see e.g. http://erpscan.com/press-center/struts2-devmode-rce-with-metasploit-module/" \
    'struts.devMode' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "struts\.devMode" \
    "1_java_struts_devMode.txt" \
    "-i"
fi

#The FLEX Flash specific stuff
if [ "$DO_FLEX" = "true" ]; then
    search 'Flex Flash has Security.allowDomain that should be tightly set and for sure not to *, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=flex' \
    'Security.allowDomain("*");' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Security\.allowDomain' \
    "3_flex_security_allowDomain.txt"
    
    search 'Flex Flash has trace to output debug info, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=flex' \
    'trace("output:" + value);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'trace\(' \
    "3_flex_trace.txt"
    
    search 'ExactSettings to false makes cross-domain attacks possible, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=flex' \
    'Security.exactSettings = false;' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Security\.exactSettings' \
    "3_flex_exactSettings.txt"
fi

#The .NET specific stuff
if [ "$DO_DOTNET" = "true" ]; then
    
    echo "#Doing .NET"
    
    search ".NET View state enable" \
    'EnableViewState' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "EnableViewState" \
    "3_dotnet_viewState.txt"
    
    search "Potentially dangerous request filter message is not poping up when disabled, which means XSS in a lot of cases." \
    'ValidateRequest' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "ValidateRequest" \
    "2_dotnet_validate_request.txt"
    
    search "If you declare a variable 'unsafe' in .NET you can do pointer arythmetic and therefore introduce buffer overflows etc. again" \
    'int unsafe bla' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "unsafe\s" \
    "2_dotnet_unsafe_declaration.txt"
    
    search "If you use Marshal in .NET you use an unsafe API and therefore you could introduce buffer overflows etc. again." \
    'Marshal' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "Marshal" \
    "2_dotnet_marshal.txt"
    
    search "If you use 'LayoutKind.Explicit' in .NET you can get memory corruption again, see http://weblog.ikvm.net/2008/09/13/WritingANETSecurityExploitPoC.aspx for an example" \
    '[StructLayout(LayoutKind.Explicit)]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "LayoutKind\.Explicit" \
    "2_dotnet_LayoutKind_explicit.txt"
    
    search "Console.WriteLine should not be used as it is only for debugging purposes, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=cs" \
    'Console.WriteLine("debug with sensitive information")' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "Console\.WriteLine" \
    "3_dotnet_console_WriteLine.txt"
    
    search "TripleDESCryptoServiceProvider, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=cs" \
    'new TripleDESCryptoServiceProvider();' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "TripleDESCryptoServiceProvider" \
    "3_dotnet_TripleDESCryptoServiceProvider.txt"
    
    search "unchecked allows to disable exceptions for integer overflows, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=cs" \
    'int d = unchecked(list.Sum()); or also as a block unchecked { int e = list.Sum(); }' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "unchecked" \
    "3_dotnet_unchecked.txt"
    
    search "Code access security permission changing via reflection, also one of the rules of https://www.owasp.org/index.php/Category:OWASP_Code_Crawler" \
    'ReflectionPermission.MemberAccess' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "ReflectionPermission" \
    "3_dotnet_ReflectionPermission.txt"
    
    search "Hidden input fields for HTML, also one of the rules of https://www.owasp.org/index.php/Category:OWASP_Code_Crawler" \
    'system.web.ui.htmlcontrols.htmlinputhidden' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "htmlinputhidden" \
    "3_dotnet_htmlinputhidden.txt"
    
    search "Configuration for request encoding, also one of the rules of https://www.owasp.org/index.php/Category:OWASP_Code_Crawler" \
    'requestEncoding' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "requestEncoding" \
    "3_dotnet_requestEncoding.txt"
    
    search "Configuration for custom errors, also one of the rules of https://www.owasp.org/index.php/Category:OWASP_Code_Crawler" \
    'CustomErrors' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "CustomErrors" \
    "3_dotnet_CustomErrors.txt"
    
    search "Used for IO in .NET, also one of the rules of https://www.owasp.org/index.php/Category:OWASP_Code_Crawler" \
    'ObjectInputStream' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "ObjectInputStream" \
    "3_dotnet_ObjectInputStream.txt"
    
    search "Used for IO in .NET, also one of the rules of https://www.owasp.org/index.php/Category:OWASP_Code_Crawler" \
    'pipedinputstream' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "pipedinputstream" \
    "3_dotnet_pipedinputstream.txt"
    
    search "Used for IO in .NET, also one of the rules of https://www.owasp.org/index.php/Category:OWASP_Code_Crawler" \
    'objectstream' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "objectstream" \
    "3_dotnet_objectstream.txt"
    
    search "Authentication as specified on https://msdn.microsoft.com/en-us/library/aa289844(v=vs.71).aspx , also one of the rules of https://www.owasp.org/index.php/Category:OWASP_Code_Crawler" \
    'Application_OnAuthenticateRequest' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "AuthenticateRequest" \
    "3_dotnet_AuthenticateRequest.txt"
    
    search "Authorization as specified on https://msdn.microsoft.com/en-us/library/system.web.httpapplication.authorizerequest(v=vs.110).aspx , also one of the rules of https://www.owasp.org/index.php/Category:OWASP_Code_Crawler" \
    'AuthorizeRequest' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "AuthorizeRequest" \
    "3_dotnet_AuthorizeRequest.txt"
    
    search "Session_OnStart as specified on https://msdn.microsoft.com/en-us/library/ms524776(v=vs.90).aspx , also one of the rules of https://www.owasp.org/index.php/Category:OWASP_Code_Crawler" \
    'Session_OnStart' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "Session_OnStart" \
    "3_dotnet_Session_OnStart.txt"
    
    search "SecurityCriticalAttribute as specified on https://msdn.microsoft.com/en-us/library/system.security.securitycriticalattribute.aspx" \
    'SecurityCriticalAttribute' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "SecurityCriticalAttribute" \
    "3_dotnet_SecurityCriticalAttribute.txt"
    
    search "SecurityPermission as specified on https://msdn.microsoft.com/en-us/library/system.security.permissions.securitypermission(v=vs.110).aspx" \
    'SecurityPermission' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "SecurityPermission" \
    "3_dotnet_SecurityPermission.txt"
    
    search "SecurityAction as specified on https://msdn.microsoft.com/en-us/library/ms182303(v=vs.80).aspx" \
    '[EnvironmentPermissionAttribute(SecurityAction.LinkDemand, Unrestricted=true)]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "SecurityAction" \
    "3_dotnet_SecurityAction.txt"
    
    search "Unmanaged memory pointers with IntPtr/UIntPtr, see https://msdn.microsoft.com/en-us/library/ms182306(v=vs.80).aspx" \
    'public IntPtr publicPointer1;' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "IntPtr" \
    "3_dotnet_IntPtr.txt"
    
    search "SQLClient, see https://msdn.microsoft.com/en-us/library/ms182310(v=vs.80).aspx" \
    'using System.Data.SqlClient;' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "SqlClient" \
    "3_dotnet_SqlClient.txt"
    
    search "SuppressUnmanagedCodeSecurityAttribute, see https://msdn.microsoft.com/en-us/library/ms182311(v=vs.80).aspx" \
    '[SuppressUnmanagedCodeSecurityAttribute()]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "SuppressUnmanagedCodeSecurityAttribute" \
    "3_dotnet_SuppressUnmanagedCodeSecurityAttribute.txt"
    
    search "UnmanagedCode, see https://msdn.microsoft.com/en-us/library/ms182312(v=vs.80).aspx" \
    '[SecurityPermissionAttribute(SecurityAction.Demand, UnmanagedCode=true)]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "UnmanagedCode" \
    "3_dotnet_UnmanagedCode.txt"
    
    search "Serializable, see https://msdn.microsoft.com/en-us/library/ms182315(v=vs.80).aspx" \
    '[Serializable]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "Serializable" \
    "3_dotnet_Serializable.txt"
    
    search "CharSet.Auto, see https://msdn.microsoft.com/en-us/library/ms182319(v=vs.80).aspx" \
    '[DllImport("advapi32.dll", CharSet=CharSet.Auto)]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "CharSet\.Auto" \
    "3_dotnet_CharSet_Auto.txt"
    
    search "DllImport, interesting to see in general, additionally see https://msdn.microsoft.com/en-us/library/ms182319(v=vs.80).aspx" \
    '[DllImport("advapi32.dll", CharSet=CharSet.Auto)]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "DllImport" \
    "3_dotnet_DllImport.txt"
    
fi

#The PHP stuff
# - php functions are case insensitive: ImAgEcReAtEfRoMpNg()
# - whitespaces can occur everywhere, eg. 5.5 (-> 5.5) is different from 5 . 5 (-> "55"), see http://stackoverflow.com/questions/4884987/php-whitespaces-that-do-matter
if [ "$DO_PHP" = "true" ]; then
    
    echo "#Doing PHP"
    
    search "Tainted input, GET URL parameter" \
    '$_GET' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\$_GET' \
    "3_php_get.txt"
    
    search "Tainted input, POST parameter" \
    '$_POST' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\$_POST' \
    "3_php_post.txt"
    
    search "Tainted input, cookie parameter" \
    '$_COOKIE' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\$_COOKIE' \
    "3_php_cookie.txt"
    
    search "Tainted input. Using \$_REQUEST is a bad idea in general, as that means GET/POST exchangeable and transporting sensitive information in the URL is a bad idea (see HTTP RFC -> ends up in logs, browser history, etc.)." \
    '$_REQUEST' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\$_REQUEST' \
    "3_php_request.txt"
    
    search "Dangerous PHP function: proc_" \
    'proc_' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'proc_' \
    "2_php_proc.txt" \
    "-i"
    
    search "Dangerous PHP function: passthru" \
    'passthru(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "passthru\s{0,$WILDCARD_SHORT}\(" \
    "2_php_passthru.txt" \
    "-i"
    
    search "Dangerous PHP function: escapeshell" \
    'escapeshell' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'escapeshell' \
    "2_php_escapeshell.txt" \
    "-i"
    
    search "Dangerous PHP function: fopen" \
    'fopen(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "fopen\s{0,$WILDCARD_SHORT}\(" \
    "2_php_fopen.txt" \
    "-i"
    
    search "Dangerous PHP function: file_get_contents" \
    'file_get_contents (' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "file_get_contents\s{0,$WILDCARD_SHORT}\(" \
    "3_php_file_get_contents.txt" \
    "-i"
    
    search "Dangerous PHP function: imagecreatefrom" \
    'imagecreatefrom' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'imagecreatefrom' \
    "3_php_imagecreatefrom.txt" \
    "-i"
    
    search "Dangerous PHP function: mkdir" \
    'mkdir (' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "mkdir\s{0,$WILDCARD_SHORT}\(" \
    "2_php_mkdir.txt" \
    "-i"
    
    search "Dangerous PHP function: chmod" \
    'chmod (' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "chmod\s{0,$WILDCARD_SHORT}\(" \
    "2_php_chmod.txt" \
    "-i"
    
    search "Dangerous PHP function: chown" \
    'chown (' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "chown\s{0,$WILDCARD_SHORT}\(" \
    "2_php_chown.txt" \
    "-i"
    
    search "Dangerous PHP function: file" \
    'file (' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "file\s{0,$WILDCARD_SHORT}\(" \
    "2_php_file.txt" \
    "-i"
    
    search "Dangerous PHP function: link" \
    'link (' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "link\s{0,$WILDCARD_SHORT}\(" \
    "2_php_link.txt" \
    "-i"
    
    search "Dangerous PHP function: rmdir" \
    'rmdir (' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "rmdir\s{0,$WILDCARD_SHORT}\(" \
    "2_php_rmdir.txt" \
    "-i"
    
    search "CURLOPT_SSL_VERIFYPEER should be set to TRUE, CURLOPT_SSL_VERIFYHOST should be set to 2, if there is a mixup, this can go really wrong. See https://crypto.stanford.edu/~dabo/pubs/abstracts/ssl-client-bugs.html" \
    'CURLOPT_SSL_VERIFYPEER' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'CURLOPT_SSL_VERIFYPEER' \
    "1_php_verifypeer-verifypeer.txt" \
    "-i"
    
    search "CURLOPT_SSL_VERIFYPEER should be set to TRUE, CURLOPT_SSL_VERIFYHOST should be set to 2, if there is a mixup, this can go really wrong. See https://crypto.stanford.edu/~dabo/pubs/abstracts/ssl-client-bugs.html" \
    'CURLOPT_SSL_VERIFYHOST' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'CURLOPT_SSL_VERIFYHOST' \
    "1_php_verifypeer-verifyhost.txt" \
    "-i"
    
    search "gnutls_certificate_verify_peers, see https://crypto.stanford.edu/~dabo/pubs/abstracts/ssl-client-bugs.html" \
    'gnutls_certificate_verify_peers' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'gnutls_certificate_verify_peers' \
    "1_php_gnutls-certificate-verify-peers.txt" \
    "-i"
    
    search "fsockopen is not checking server certificates if used with a ssl:// URL. See https://crypto.stanford.edu/~dabo/pubs/abstracts/ssl-client-bugs.html" \
    'fsockopen (' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "fsockopen\s{0,$WILDCARD_SHORT}\(" \
    "1_php_fsockopen.txt" \
    "-i"
    
    search "You can make a lot of things wrong with include" \
    'include (' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "include\s{0,$WILDCARD_SHORT}\(" \
    "2_php_include.txt" \
    "-i"
    
    search "You can make a lot of things wrong with include_once" \
    'include_once (' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "include_once\s{0,$WILDCARD_SHORT}\(" \
    "2_php_include_once.txt" \
    "-i"
    
    search "You can make a lot of things wrong with require" \
    'require (' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "require\s{0,$WILDCARD_SHORT}\(" \
    "2_php_require.txt" \
    "-i"
    
    search "You can make a lot of things wrong with require_once" \
    'require_once (' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "require_once\s{0,$WILDCARD_SHORT}\(" \
    "2_php_require_once.txt" \
    "-i"
    
    search "Methods that often introduce XSS: echo" \
    'echo' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "echo" \
    "4_php_echo_high_volume.txt" \
    "-i"
    
    search "Methods that often introduce XSS: echo in combination with \$_POST." \
    'echo $_POST["ABC"]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "echo.{0,$WILDCARD_LONG}\\\$_POST" \
    "1_php_echo_low_volume_POST.txt" \
    "-i"
    
    search "Methods that often introduce XSS: echo in combination with \$_GET." \
    'echo $_GET["ABC"]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "echo.{0,$WILDCARD_LONG}\\\$_GET" \
    "1_php_echo_low_volume_GET.txt" \
    "-i"
    
    search "Methods that often introduce XSS: echo in combination with \$_COOKIE. And there is no good explanation usually why a cookie is printed to the HTML anyway (debug interface?)." \
    'echo $_COOKIE["ABC"]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "echo.{0,$WILDCARD_LONG}\\\$_COOKIE" \
    "1_php_echo_low_volume_COOKIE.txt" \
    "-i"
    
    search "Methods that often introduce XSS: echo in combination with \$_REQUEST." \
    'echo $_REQUEST["ABC"]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "echo.{0,$WILDCARD_LONG}\\\$_REQUEST" \
    "1_php_echo_low_volume_REQUEST.txt" \
    "-i"
    
    search "Methods that often introduce XSS: print" \
    'print' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "print" \
    "4_php_print_high_volume.txt" \
    "-i"
    
    search "Methods that often introduce XSS: print in combination with \$_POST." \
    'print $_POST["ABC"]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "print.{0,$WILDCARD_LONG}\\\$_POST" \
    "1_php_print_low_volume_POST.txt" \
    "-i"
    
    search "Methods that often introduce XSS: print in combination with \$_GET." \
    'print $_GET["ABC"]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "print.{0,$WILDCARD_LONG}\\\$_GET" \
    "1_php_print_low_volume_GET.txt" \
    "-i"
    
    search "Methods that often introduce XSS: print in combination with \$_COOKIE. And there is no good explanation usually why a cookie is printed to the HTML anyway (debug interface?)." \
    'print $_COOKIE["ABC"]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "print.{0,$WILDCARD_LONG}\\\$_COOKIE" \
    "1_php_print_low_volume_COOKIE.txt" \
    "-i"
    
    search "Methods that often introduce XSS: print in combination with \$_REQUEST. Don't use \$_REQUEST in general." \
    'print $_REQUEST["ABC"]' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "print.{0,$WILDCARD_LONG}\\\$_REQUEST" \
    "1_php_print_low_volume_REQUEST.txt" \
    "-i"
    
    search "Databases in PHP: pg_query" \
    'pg_query(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "pg_query\s{0,$WILDCARD_SHORT}\(" \
    "3_php_sql_pg_query.txt" \
    "-i"
    
    search "Databases in PHP: mysqli_" \
    'mysqli_method(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "mysqli_.{1,$WILDCARD_SHORT}\(" \
    "3_php_sql_mysqli.txt" \
    "-i"
    
    search "Databases in PHP: mysql_" \
    'mysql_method(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "mysql_.{1,$WILDCARD_SHORT}\(" \
    "3_php_sql_mysql.txt" \
    "-i"
    
    search "Databases in PHP: mssql_" \
    'mssql_method(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "mssql_.{1,$WILDCARD_SHORT}\(" \
    "3_php_sql_mssql.txt" \
    "-i"
    
    search "Databases in PHP: odbc_exec" \
    'odbc_exec(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "odbc_exec\s{0,$WILDCARD_SHORT}\(" \
    "3_php_sql_odbc_exec.txt" \
    "-i"
    
    search "PHP rand(): This is not a secure random." \
    'rand(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "rand\s{0,$WILDCARD_SHORT}\(" \
    "3_php_rand.txt" \
    "-i"
    
    search "Extract can be dangerous and could be used as backdoor, see http://blog.sucuri.net/2014/02/php-backdoors-hidden-with-clever-use-of-extract-function.html#null" \
    'extract(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "extract\s{0,$WILDCARD_SHORT}\(" \
    "3_php_extract.txt" \
    "-i"
    
    search "Assert can be used as backdoor, see http://rileykidd.com/2013/08/21/the-backdoor-you-didnt-grep/" \
    'assert(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "assert\s{0,$WILDCARD_SHORT}\(" \
    "3_php_assert.txt" \
    "-i"
    
    search "Preg_replace can be used as backdoor, see http://labs.sucuri.net/?note=2012-05-21" \
    'preg_replace(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "preg_replace\s{0,$WILDCARD_SHORT}\(" \
    "3_php_preg_replace.txt" \
    "-i"
    
    search "The big problem with == is that in PHP (and some other languages), this comparison is not type safe. What you should always use is ===. For example a hash value that starts with 0E could be interpreted as an integer if you don't take care. There were real world bugs exploiting this issue already, think login form and comparing the hashed user password, what happens if you type in 0 as the password and brute force different usernames until a user has a hash which starts with 0E?" \
    'hashvalue_from_db == PBKDF2(password_from_login_http_request)' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "[^=]==[^=]" \
    "4_php_type_unsafe_comparison.txt"
fi

#The HTML specific stuff
if [ "$DO_HTML" = "true" ]; then
    
    echo "#Doing HTML"
    
    search "HTML upload." \
    'enctype="multipart/form-data"' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "multipart/form-data" \
    "2_html_upload_form_tag.txt" \
    "-i"
    
    search "HTML upload form." \
    '<input name="param" type="file"' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "type=.?file" \
    "3_html_upload_input_tag.txt" \
    "-i"
    
    search "Autocomplete should be set to off for password fields." \
    'autocomplete' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'autocomplete' \
    "5_html_autocomplete.txt" \
    "-i"
    
    search "Angular.js has this Strict Contextual Escaping (SCE) that should prevent ." \
    '$sceProvider.enabled(false)' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'sceProvider\.enabled\(' \
    "3_angularjs_sceprovider_enabled.txt" \
    "-i"
    
    search 'From the Angular.js explanation for Strict Contextual Escaping (SCE): You can then audit your code (a simple grep would do) to ensure that this is only done for those values that you can easily tell are safe - because they were received from your server, sanitized by your library, etc. [...] In the case of AngularJS SCE service, one uses {@link ng.$sce#trustAs $sce.trustAs} (and shorthand methods such as {@link ng.$sce#trustAsHtml $sce.trustAsHtml}, etc.) to obtain values that will be accepted by SCE / privileged contexts.' \
    '$sce.trustAsHtml' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'sce\.trustAs' \
    "3_angularjs_sceprovider_check_all_instances_of_unsafe_html_1.txt" \
    "-i"
    
    search 'From the Angular.js explanation for Strict Contextual Escaping (SCE): You can then audit your code (a simple grep would do) to ensure that this is only done for those values that you can easily tell are safe - because they were received from your server, sanitized by your library, etc. [...] In the case of AngularJS SCE service, one uses {@link ng.$sce#trustAs $sce.trustAs} (and shorthand methods such as {@link ng.$sce#trustAsHtml $sce.trustAsHtml}, etc.) to obtain values that will be accepted by SCE / privileged contexts.' \
    'ng.$sce#trustAs' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'sce#trustAs' \
    "3_angularjs_sceprovider_check_all_instances_of_unsafe_html_2.txt" \
    "-i"
    
fi

#JavaScript specific stuff
if [ "$DO_JAVASCRIPT" = "true" ]; then
    
    echo "#Doing JavaScript"
    
    search "Location hash: DOM-based XSS source/sink." \
    'location.hash' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'location\.hash' \
    "4_js_dom_xss_location-hash.txt"
    
    search "Location href: DOM-based XSS source/sink." \
    'location.href' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'location\.href' \
    "4_js_dom_xss_location-href.txt"
    
    search "Location pathname: DOM-based XSS source/sink." \
    'location.pathname' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'location\.pathname' \
    "4_js_dom_xss_location-pathname.txt"
    
    search "Location search: DOM-based XSS source/sink." \
    'location.search' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'location\.search' \
    "4_js_dom_xss_location-search.txt"
    
    search "appendChild: DOM-based XSS sink." \
    '.appendChild(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.appendChild\(' \
    "4_js_dom_xss_appendChild.txt"
    
    search "Document location: DOM-based XSS source/sink." \
    'document.location' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'document\.location' \
    "4_js_dom_xss_document_location.txt"
    
    search "Window location: DOM-based XSS source/sink." \
    'window.location' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'window\.location' \
    "4_js_dom_xss_window-location.txt"
    
    search "Document referrer: DOM-based XSS source/sink." \
    'document.referrer' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'document\.referrer' \
    "4_js_dom_xss_document-referrer.txt"
    
    search "Document URL: DOM-based XSS source/sink." \
    'document.URL' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'document\.URL' \
    "4_js_dom_xss_document-URL.txt"
    
    search "Document Write and variants of it: DOM-based XSS source/sink." \
    'document.writeln(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'document\.writel?n?\(' \
    "4_js_dom_xss_document-write.txt"
    
    search "InnerHTML: DOM-based XSS source/sink." \
    '.innerHTML =' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.innerHTML\s{0,$WILDCARD_SHORT}=" \
    "4_js_dom_xss_innerHTML.txt"
    
    search "OuterHTML: DOM-based XSS source/sink." \
    '.outerHTML =' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.outerHTML\s{0,$WILDCARD_SHORT}=" \
    "4_js_dom_xss_outerHTML.txt"
    
    search "Console should not be logged to in production" \
    'console.log(user_password);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "console\." \
    "4_js_console.txt"
    
    search "The postMessage in JavaScript should explicitly not be used with targetOrigin set to * and check how messages are exchanged, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=js" \
    'aWindow.postMessage(message, "*");' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\.postMessage\(" \
    "4_js_postMessage.txt"
    
    search "The debugger statement is basically a breakpoint, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=js" \
    'debugger;' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "debugger;" \
    "4_js_debugger.txt"
    
    search "The constructor for functions can be used as a replacement for eval, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=js" \
    'f = new Function("name", "return 123 + name"); ' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "new\sFunction.{0,$WILDCARD_SHORT}" \
    "3_js_new_function_eval.txt"
    
    search "Sensitive information in localStorage is not encrypted, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=js" \
    'localStorage.setItem("data", sensitive_data); ' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "localStorage" \
    "3_js_localStorage.txt"
    
    search "Sensitive information in sessionStorage is not encrypted, see https://sonarqube.com/coding_rules#types=VULNERABILITY|languages=js" \
    'sessionStorage.setItem("data", sensitive_data); ' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "sessionStorage" \
    "3_js_sessionStorage.txt"

    search "Dynamic creation of script tag, where is it loading JavaScript from?" \
    'elem = createElement("script");' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "createElement.{0,$WILDCARD_SHORT}script" \
    "3_js_createElement_script.txt"

fi

if [ "$DO_MODSECURITY" = "true" ]; then
    
    echo "#Doing modsecurity"
    
    search "Block is not recommended to use because it is depending on default action, use deny (or allow)" \
    'block' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'block' \
    "3_modsecurity_block.txt" \
    "-i"
    
    search "Rather complex modsecurity constructs that are worth having a look." \
    'ctl:auditEngine' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'ctl:auditEngine' \
    "3_modsecurity_ctl_auditEngine.txt" \
    "-i"
    
    search "Rather complex modsecurity constructs that are worth having a look." \
    'ctl:ruleEngine' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'ctl:ruleEngine' \
    "3_modsecurity_ctl_ruleEngine.txt" \
    "-i"
    
    search "Rather complex modsecurity constructs that are worth having a look." \
    'ctl:ruleRemoveById' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'ctl:ruleRemoveById' \
    "3_modsecurity_ctl_ruleRemoveById.txt" \
    "-i"
    
    search "Possible command injection when executing bash scripts." \
    'exec:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'exec:' \
    "4_modsecurity_exec.txt" \
    "-i"
    
    search "Modsecurity actively changing HTTP response content." \
    'append:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'append:' \
    "4_modsecurity_append.txt" \
    "-i"
    
    search "Modsecurity actively changing HTTP response content." \
    'SecContentInjection' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'SecContentInjection' \
    "4_modsecurity_SecContentInjection.txt" \
    "-i"
    
    #Take care with the following regex, @ has a special meaning in double quoted strings, but not in single quoted strings
    search "Modsecurity inspecting uploaded files." \
    '@inspectFile' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '@inspectFile' \
    "4_modsecurity_inspectFile.txt" \
    "-i"
    
    search "Modsecurity audit configuration information." \
    'SecAuditEngine' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'SecAuditEngine' \
    "4_modsecurity_SecAuditEngine.txt" \
    "-i"
    
    search "Modsecurity audit configuration information." \
    'SecAuditLogParts' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'SecAuditLogParts' \
    "4_modsecurity_SecAuditLogParts.txt" \
    "-i"
    
fi

#mobile device stuff
if [ "$DO_MOBILE" = "true" ]; then
    
    echo "#Doing mobile"
    
    search "Root detection." \
    'root detection' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "root.{0,$WILDCARD_SHORT}detection" \
    "2_mobile_root_detection_root-detection.txt" \
    "-i"
    
    search "Root detection." \
    'RootedDevice' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "root.{0,$WILDCARD_SHORT}Device" \
    "2_mobile_root_detection_root-device.txt" \
    "-i"
    
    search "Root detection." \
    'isRooted' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "is.{0,$WILDCARD_SHORT}rooted" \
    "2_mobile_root_detection_isRooted.txt" \
    "-i"
    
    search "Root detection." \
    'detect root' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "detect.{0,$WILDCARD_SHORT}root" \
    "2_mobile_root_detection_detectRoot.txt" \
    "-i"
    
    search "Jailbreak." \
    'jail_break' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "jail.{0,$WILDCARD_SHORT}break" \
    "2_mobile_jailbreak.txt" \
    "-i"
    
fi

#The Android specific stuff
if [ "$DO_ANDROID" = "true" ]; then
    #For interesting inputs see:
    # http://developer.android.com/training/articles/security-tips.html
    # http://source.android.com/devices/tech/security/
    
    echo "#Doing Android"
    
    search "From http://developer.android.com/reference/android/util/Log.html : The order in terms of verbosity, from least to most is ERROR, WARN, INFO, DEBUG, VERBOSE. Verbose should never be compiled into an application except during development. Debug logs are compiled in but stripped at runtime. Error, warning and info logs are always kept." \
    'Log.e(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Log\.e\(' \
    "3_android_logging_error.txt"
    
    search "From http://developer.android.com/reference/android/util/Log.html : The order in terms of verbosity, from least to most is ERROR, WARN, INFO, DEBUG, VERBOSE. Verbose should never be compiled into an application except during development. Debug logs are compiled in but stripped at runtime. Error, warning and info logs are always kept." \
    'Log.w(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Log\.w\(' \
    "3_android_logging_warning.txt"
    
    search "From http://developer.android.com/reference/android/util/Log.html : The order in terms of verbosity, from least to most is ERROR, WARN, INFO, DEBUG, VERBOSE. Verbose should never be compiled into an application except during development. Debug logs are compiled in but stripped at runtime. Error, warning and info logs are always kept." \
    'Log.i(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Log\.i\(' \
    "3_android_logging_information.txt"
    
    search "From http://developer.android.com/reference/android/util/Log.html : The order in terms of verbosity, from least to most is ERROR, WARN, INFO, DEBUG, VERBOSE. Verbose should never be compiled into an application except during development. Debug logs are compiled in but stripped at runtime. Error, warning and info logs are always kept." \
    'Log.d(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Log\.d\(' \
    "3_android_logging_debug.txt"
    
    search "From http://developer.android.com/reference/android/util/Log.html : The order in terms of verbosity, from least to most is ERROR, WARN, INFO, DEBUG, VERBOSE. Verbose should never be compiled into an application except during development. Debug logs are compiled in but stripped at runtime. Error, warning and info logs are always kept." \
    'Log.v(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Log\.v\(' \
    "3_android_logging_verbose.txt"
    
    search "File MODE_PRIVATE for file access on Android, see https://developer.android.com/reference/android/content/Context.html" \
    'MODE_PRIVATE' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'MODE_PRIVATE' \
    "3_android_access_mode-private.txt"
    
    search "File MODE_WORLD_READABLE for file access on Android, see https://developer.android.com/reference/android/content/Context.html" \
    'MODE_WORLD_READABLE' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'MODE_WORLD_READABLE' \
    "1_android_access_mode-world-readable.txt"
    
    search "File MODE_WORLD_WRITEABLE for file access on Android, see https://developer.android.com/reference/android/content/Context.html" \
    'MODE_WORLD_WRITEABLE' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'MODE_WORLD_WRITEABLE' \
    "1_android_access_mode-world-writeable.txt"
    
    search "Opening files via URI on Android, see https://developer.android.com/reference/android/content/ContentProvider.html#openFile%28android.net.Uri,%20java.lang.String%29" \
    '.openFile(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.openFile\(' \
    "3_android_access_openFile.txt"
    
    search "Opening an asset files on Android, see https://developer.android.com/reference/android/content/ContentProvider.html" \
    '.openAssetFile(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.openAssetFile\(' \
    "3_android_access_openAssetFile.txt"
    
    search "Android database open or create" \
    '.openOrCreate' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.openOrCreate' \
    "3_android_access_openOrCreate.txt"
    
    search "Android get database" \
    '.getDatabase(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.getDatabase\(' \
    "3_android_access_getDatabase.txt"
    
    search "Android open database (and btw. a deprecated W3C standard that was never really implemented in a lot of browsers for JavaScript for local storage)" \
    '.openDatabase(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.openDatabase\(' \
    "3_android_access_openDatabase.txt"
    
    search "Get shared preferences on Android, see https://developer.android.com/reference/android/content/SharedPreferences.html" \
    '.getShared' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.getShared' \
    "3_android_access_getShared.txt"
    
    search "Get cache directory on Android, see https://developer.android.com/reference/android/content/Context.html" \
    'context.getCacheDir()' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.getCache' \
    "3_android_access_getCache.txt"
    
    search "Get code cache directory on Android, see https://developer.android.com/reference/android/content/Context.html" \
    '.getCodeCache' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.getCodeCache' \
    "3_android_access_getCodeCache.txt"
    
    search "Get external cache directory on Android, see https://developer.android.com/reference/android/content/Context.html" \
    '.getExternalCache' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.getExternalCache' \
    "3_android_access_getExternalCache.txt"
    
    search "Do a query on Android" \
    '.query(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'query\(' \
    "3_android_access_query.txt"
    
    search "RawQuery. If the first argument to rawQuery is a user suplied input, it's an SQL injection." \
    'rawQuery(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'rawQuery\(' \
    "3_android_access_rawQuery.txt"
    
    search "RawQueryWithFactory. If the second argument to rawQueryWithFactory is a user suplied input, it's an SQL injection." \
    'rawQueryWithFactory(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'rawQueryWithFactory\(' \
    "3_android_access_rawQueryWithFactory.txt"
    
    search "Android compile SQL statement" \
    'compileStatement(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'compileStatement\(' \
    "3_android_access_compileStatement.txt"
    
    search "Registering receivers and sending broadcasts can be dangerous when exported. See http://resources.infosecinstitute.com/android-hacking-security-part-3-exploiting-broadcast-receivers/" \
    'android:exported=true' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "android:exported.{0,$WILDCARD_SHORT}true" \
    "3_android_intents_intent-filter_exported.txt" \
    "-i"
    
    search "Registering receivers and sending broadcasts can be dangerous when exported. See http://resources.infosecinstitute.com/android-hacking-security-part-3-exploiting-broadcast-receivers/" \
    'registerReceiver(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "registerReceiver\(" \
    "3_android_intents_intent-filter_registerReceiver.txt" \
    "-i"
    
    search "Registering receivers and sending broadcasts can be dangerous when exported. See http://resources.infosecinstitute.com/android-hacking-security-part-3-exploiting-broadcast-receivers/" \
    'sendBroadcast(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "sendBroadcast\(" \
    "3_android_intents_intent-filter_sendBroadcast.txt" \
    "-i"
    
    search "Android get intent" \
    '.getIntent(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.getIntent\(' \
    "3_android_intents_getIntent.txt"
    
    search "Android get data from an intent" \
    '.getData(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.getData\(' \
    "3_android_intents_getData.txt"
    
    search "Android get info about running processes" \
    'RunningAppProcessInfo' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'RunningAppProcessInfo' \
    "3_android_intents_RunningAppProcessInfo.txt"
    
    search "Methods to overwrite SSL certificate checks." \
    'X509TrustManager' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'X509TrustManager' \
    "2_android_ssl_x509TrustManager.txt"
    
    search "Android get a key store" \
    'KeyStore' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'KeyStore' \
    "2_android_ssl_keyStorage.txt"
    
    search "Insecure hostname verification." \
    'ALLOW_ALL_HOSTNAME_VERIFIER' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'ALLOW_ALL_HOSTNAME_VERIFIER' \
    "1_android_ssl_hostname_verifier.txt"
    
    search "Implementation of SSL trust settings." \
    'implements TrustStrategy' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'implements TrustStrategy' \
    "2_android_ssl_trustStrategy.txt"
    
    search "Used to query other appps or let them query, see http://developer.android.com/guide/topics/providers/content-provider-basics.html" \
    'ContentResolver' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'ContentResolver' \
    "3_android_contentResolver.txt"
    
    search "Debuggable webview, see https://developer.chrome.com/devtools/docs/remote-debugging#debugging-webviews" \
    '.setWebContentsDebuggingEnabled(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\.setWebContentsDebuggingEnabled\(' \
    "1_android_setWebContentsDebuggingEnabled.txt"
    
    search "If an Android app wants to specify how the app is backuped, you use BackupAgent to interfere... Often shows which sensitive data is not written to the backup. See https://developer.android.com/reference/android/app/backup/BackupAgent.html" \
    'new BackupAgent()' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "BackupAgent" \
    "3_android_backupAgent.txt"
    
    search "/system is the path where a lot of binaries are stored. So whenever an Android app does something like executing a binary such as /system/xbin/which with an absolut path. Often used in root-detection mechanisms." \
    '/system/xbin/which' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "/system" \
    "3_android_system_path.txt"
    
    search "Often used in root-detection mechanisms." \
    'Superuser.apk' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "Superuser.apk" \
    "3_android_superuser_apk.txt" \
    "-i"
    
    search "Often used in root-detection mechanisms." \
    'eu.chainfire.supersu' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "supersu" \
    "3_android_supersu.txt"
    
    search "Often used in root-detection mechanisms. geprop ro.secure on an adb shell can be used to check. If ro.secure=0, an ADB shell will run commands as the root user on the device. But if ro.secure=1, an ADB shell will run commands as an unprivileged user on the device." \
    'ro.secure' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "ro\.secure" \
    "3_android_ro.secure.txt"
    
    search "Often used in root-detection mechanisms, checks if debugger is connected." \
    'android.os.Debug.isDebuggerConnected()' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "isDebuggerConnected" \
    "3_android_isDebuggerConnected.txt"
    
    search "Probably the singlemost effective root-detection mechanism, implemented by Google itself, SafetyNet. See https://developer.android.com/training/safetynet/index.html and https://koz.io/inside-safetynet/ ." \
    'mGoogleApiClient = new GoogleApiClient.Builder(this).addApi(SafetyNet.API)' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "SafetyNet" \
    "2_android_SafetyNet.txt"
    
    search "Probably the singlemost effective root-detection mechanism, implemented by Google itself, SafetyNet. See https://developer.android.com/training/safetynet/index.html and https://koz.io/inside-safetynet/ ." \
    'public void onResult(SafetyNetApi.AttestationResult result) {' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "AttestationResult" \
    "2_android_AttestationResult.txt"
    
fi

#The iOS specific stuff
if [ "$DO_IOS" = "true" ]; then
    
    echo "#Doing iOS"
    
    search "iOS File protection APIs" \
    'NSFileProtection' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'NSFileProtection' \
    "3_ios_file_access_nsfileprotection.txt"
    
    search "iOS File protection APIs" \
    'NSFileManager' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'NSFileManager' \
    "3_ios_file_access_nsfilemanager.txt"
    
    search "iOS File protection APIs" \
    'NSPersistantStoreCoordinator' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'NSPersistantStoreCoordinator' \
    "3_ios_file_access_nspersistantstorecoordinator.txt"
    
    search "iOS File protection APIs" \
    'NSData' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'NSData' \
    "3_ios_file_access_nsdata.txt"
    
    search "iOS Keychain stuff" \
    'kSecAttrAccessible' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'kSecAttrAccessible' \
    "3_ios_keychain_ksecattraccessible.txt"
    
    search "iOS Keychain stuff" \
    'SecItemAdd' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'SecItemAdd' \
    "3_ios_keychain_secitemadd.txt"
    
    search "iOS Keychain stuff" \
    'KeychainItemWrapper' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'KeychainItemWrapper' \
    "3_ios_keychain_KeychainItemWrapper.txt"
    
    search "iOS Keychain stuff" \
    'Security.h' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Security\.h' \
    "3_ios_keychain_security_h.txt"
    
    search "CFBundleURLSchemes" \
    'CFBundleURLSchemes' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'CFBundleURLSchemes' \
    "3_ios_CFBundleURLSchemes.txt"
    
    search "kCFStream" \
    'kCFStream' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'kCFStream' \
    "3_ios_kCFStream.txt"
    
    search "CFFTPStream" \
    'CFFTPStream' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'CFFTPStream' \
    "3_ios_CFFTPStream.txt"
    
    search "CFHTTP" \
    'CFHTTP' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'CFHTTP' \
    "3_ios_CFHTTP.txt"
    
    search "CFNetServices" \
    'CFNetServices' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'CFNetServices' \
    "3_ios_CFNetServices.txt"
    
    search "FTPURL" \
    'FTPURL' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'FTPURL' \
    "3_ios_FTPURL.txt"
    
    search "IOBluetooth" \
    'IOBluetooth' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'IOBluetooth' \
    "3_ios_IOBluetooth.txt"
    
    search "NSLog" \
    'NSLog(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'NSLog\(' \
    "3_ios_NSLog.txt"
    
    search "iOS string format function initWithFormat. Just check if the first argument to these functions are user controlled, that could be a format string vulnerability." \
    'initWithFormat:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'initWithFormat:' \
    "3_ios_string_format_initWithFormat.txt"
    
    search "iOS string format function informativeTextWithFormat. Just check if the first argument to these functions are user controlled, that could be a format string vulnerability." \
    'informativeTextWithFormat:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'informativeTextWithFormat:' \
    "3_ios_string_format_informativeTextWithFormat.txt"
    
    search "iOS string format function format. Just check if the first argument to these functions are user controlled, that could be a format string vulnerability." \
    'format:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'format:' \
    "3_ios_string_format_format.txt"
    
    search "iOS string format function stringWithFormat. Just check if the first argument to these functions are user controlled, that could be a format string vulnerability." \
    'stringWithFormat:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'stringWithFormat:' \
    "3_ios_string_format_stringWithFormat.txt"
    
    search "iOS string format function appendFormat. Just check if the first argument to these functions are user controlled, that could be a format string vulnerability." \
    'appendFormat:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'appendFormat:' \
    "3_ios_string_format_appendFormat.txt"
    
    search "iOS string format function predicateWithFormat. Just check if the first argument to these functions are user controlled, that could be a format string vulnerability." \
    'predicateWithFormat:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'predicateWithFormat:' \
    "3_ios_string_format_predicateWithFormat.txt"
    
    search "iOS string format function NSRunAlertPanel. Just check if the first argument to these functions are user controlled, that could be a format string vulnerability." \
    'NSRunAlertPanel' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'NSRunAlertPanel' \
    "3_ios_string_format_NSRunAlertPanel.txt"
    
    search "iOS string format function handleOpenURL. Just check if the first argument to these functions are user controlled, that could be a format string vulnerability." \
    'handleOpenURL:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'handleOpenURL:' \
    "3_ios_string_format_url_handler_handleOpenURL.txt"
    
    search "iOS string format function openURL. Just check if the first argument to these functions are user controlled, that could be a format string vulnerability." \
    'openURL:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'openURL:' \
    "3_ios_string_format_url_handler_openURL.txt"
    
    search "NSAllowsArbitraryLoads set to 1 allows iOS applications to load resources over insecure non-TLS protocols." \
    'NSAllowsArbitraryLoads' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'NSAllowsArbitraryLoads' \
    "2_ios_NSAllowsArbitraryLoads.txt"

fi

#Python language specific stuff
#- whitespaces are allowed between function names and brackets: abs (-1.3) 
#- Function names are case sensitive
#- Due to the many flexible way of calling a function, the regexes will only catch "the most natural" case
if [ "$DO_PYTHON" = "true" ]; then
    
    echo "#Doing python"
    
    search "Input function in Python 2.X is dangerous (but not in python 3.X), as it read from stdin and then evals the input, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'input()' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "input\s{0,$WILDCARD_SHORT}\(" \
    "3_python_input_function.txt"
    
    search "Assert statements are not compiled into the optimized byte code, therefore can not be used for security purposes, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'assert variable and other' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "assert\s{1,$WILDCARD_SHORT}" \
    "3_python_assert_statement.txt"
    
    search "The 'is' object identity operator should not be used for numbers, see https://access.redhat.com/blogs/766093/posts/2592591" \
    '1+1 is 2' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\d\s{1,$WILDCARD_SHORT}is\s{1,$WILDCARD_SHORT}" \
    "2_python_is_object_identity_operator_left.txt"
    
    search "The 'is' object identity operator should not be used for numbers, see https://access.redhat.com/blogs/766093/posts/2592591" \
    '1+1 is 2' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\s{1,$WILDCARD_SHORT}is\s{1,$WILDCARD_SHORT}\d" \
    "2_python_is_object_identity_operator_right.txt"
    
    search "The 'is' object identity operator should not be used for numbers, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'object.an_integer is other_object.other_integer' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\sis\s" \
    "5_python_is_object_identity_operator_general.txt"
    
    search "The float type can not be reliably compared for equality, see https://access.redhat.com/blogs/766093/posts/2592591" \
    '2.2 * 3.0 == 3.3 * 2.2' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\d\.\d{1,$WILDCARD_SHORT}\s{1,$WILDCARD_SHORT}==\s{1,$WILDCARD_SHORT}" \
    "2_python_float_equality_left.txt"
    
    search "The float type can not be reliably compared for equality, see https://access.redhat.com/blogs/766093/posts/2592591" \
    '2.2 * 3.0 == 3.3 * 2.2' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\s{1,$WILDCARD_SHORT}==\s{1,$WILDCARD_SHORT}\d\.\d{1,$WILDCARD_SHORT}" \
    "2_python_float_equality_right.txt"
    
    search "The float type can not be reliably compared for equality. Make sure none of these comparisons uses floats, see https://access.redhat.com/blogs/766093/posts/2592591" \
    '2.2 * 3.0 == 3.3 * 2.2' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\s{1,$WILDCARD_SHORT}==\s{1,$WILDCARD_SHORT}" \
    "2_python_float_equality_general.txt"
    
    search "Double underscore variable visibility can be tricky, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'self.__private' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "self\.__" \
    "4_python_double_underscore_general.txt"
    
    search "Doing things with __code__ is very low level" \
    'object.__code__' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "__code__" \
    "3_python_double_underscore_code.txt"
    
    search "The shell=True named argument of the subprocess module makes command injection possible, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'subprocess.call(unvalidated_input, shell=True)' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "shell=True" \
    "3_python_subprocess_shell_true.txt"
    
    search "mktemp of the tempfile module is flawed, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'tempfile.mktemp()' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "mktemp\s{0,$WILDCARD_SHORT}\(" \
    "3_python_tempfile_mktemp.txt"
    
    search "shutil.copyfile is flawed as it creates the destination in the most insecure manner possible, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'shutil.copyfile(src, dst)' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "copyfile\s{0,$WILDCARD_SHORT}\(" \
    "3_python_shutil_copyfile.txt"
    
    search "shutil.move is flawed and silently leaves the old file behind if the source and destination are on different file systems, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'shutil.move(src, dst)' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "move\s{0,$WILDCARD_SHORT}\(" \
    "3_python_shutil_move.txt"
    
    search "yaml.load is flawed and uses pickle to deserialize its data, which leads to code execution, see https://access.redhat.com/blogs/766093/posts/2592591 . The proper way is to use safe_load." \
    'import yaml' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "import\s{0,$WILDCARD_SHORT}yaml" \
    "3_python_yaml_import.txt"
    
    search "pickle leads to code execution if untrusted input is deserialized, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'import pickle' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "import\s{0,$WILDCARD_SHORT}pickle" \
    "3_python_pickle_import.txt"
    
    search "pickle leads to code execution if untrusted input is deserialized, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'from pickle' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "from\s{0,$WILDCARD_SHORT}pickle" \
    "3_python_pickle_from.txt"
    
    search "shelve leads to code execution if untrusted input is deserialized, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'import shelve' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "import\s{0,$WILDCARD_SHORT}shelve" \
    "3_python_shelve_import.txt"
    
    search "shelve leads to code execution if untrusted input is deserialized, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'from shelve' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "from\s{0,$WILDCARD_SHORT}shelve" \
    "3_python_shelve_from.txt"
    
    search "jinja2 in its default configuration leads to XSS if untrusted input is used for rendering, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'import jinja2' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "import\s{0,$WILDCARD_SHORT}jinja2" \
    "3_python_jinja2_import.txt"
    
    search "jinja2 in its default configuration leads to XSS if untrusted input is used for rendering, see https://access.redhat.com/blogs/766093/posts/2592591" \
    'from jinja2' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "from\s{0,$WILDCARD_SHORT}jinja2" \
    "3_python_jinja2_from.txt"
    
fi

#The ruby part
#ruby is case sensitive in general
#If you have a ruby application, the static analyzer https://github.com/presidentbeef/brakeman seems pretty promising
if [ "$DO_RUBY" = "true" ]; then

    echo "#Doing ruby"
    
    search "Basic authentication in ruby with http_basic_authenticate_with" \
    'http_basic_authenticate_with' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "http_basic_authenticate_with" \
    "2_ruby_http_basic_authenticate_with.txt"
    
    search "Content tag can lead to XSS, see https://github.com/presidentbeef/brakeman/blob/master/lib/brakeman/checks/check_content_tag.rb" \
    'content_tag :tag, body' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "content_tag" \
    "2_ruby_content_tag.txt"
    
    search "Possible deserialization issues, see https://github.com/presidentbeef/brakeman/blob/master/lib/brakeman/checks/check_deserialize.rb" \
    ':YAML' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    ":YAML" \
    "2_ruby_yaml.txt"
    
    search "Possible deserialization issues, see https://github.com/presidentbeef/brakeman/blob/master/lib/brakeman/checks/check_deserialize.rb" \
    ':load' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    ":load" \
    "2_ruby_load.txt"
    
    search "Possible deserialization issues, see https://github.com/presidentbeef/brakeman/blob/master/lib/brakeman/checks/check_deserialize.rb" \
    ':load_documents' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    ":load_documents" \
    "2_ruby_load_documents.txt"
    
    search "Possible deserialization issues, see https://github.com/presidentbeef/brakeman/blob/master/lib/brakeman/checks/check_deserialize.rb" \
    ':load_stream' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    ":load_stream" \
    "2_ruby_load_stream.txt"
    
    search "Possible deserialization issues, see https://github.com/presidentbeef/brakeman/blob/master/lib/brakeman/checks/check_deserialize.rb" \
    ':parse_documents' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    ":parse_documents" \
    "2_ruby_parse_documents.txt"
    
    search "Possible deserialization issues, see https://github.com/presidentbeef/brakeman/blob/master/lib/brakeman/checks/check_deserialize.rb" \
    ':parse_stream' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    ":parse_stream" \
    "2_ruby_parse_stream.txt"
    
    search "Detailed exceptions shown, see https://github.com/presidentbeef/brakeman/blob/master/lib/brakeman/checks/check_detailed_exceptions.rb" \
    ':show_detailed_exceptions' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    ":show_detailed_exceptions" \
    "2_ruby_show_detailed_exceptions.txt"
    
    search "Spawning a subshell? See https://github.com/presidentbeef/brakeman/blob/master/lib/brakeman/checks/check_execute.rb" \
    ':capture2e' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    ":capture" \
    "2_ruby_capture.txt"
    
    search "XSRF protection in ruby. See http://api.rubyonrails.org/classes/ActionController/RequestForgeryProtection/ClassMethods.html" \
    'protect_from_forgery' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "protect_from_forgery" \
    "2_ruby_protect_from_forgery.txt"
    
    search "HTTP redirects in ruby. See https://github.com/presidentbeef/brakeman/blob/master/lib/brakeman/checks/check_redirect.rb" \
    ':redirect_to' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    ":redirect_to" \
    "2_ruby_redirect_to.txt"
    
    search "Authenticity token verficiation skipped? See https://github.com/presidentbeef/brakeman/blob/master/lib/brakeman/checks/check_skip_before_filter.rb" \
    'verify_authenticity_token' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "verify_authenticity_token" \
    "2_ruby_verify_authenticity_token.txt"

    search "Regex function that allows anything after a newline, \\A and \\z has to be used in regex to prevent this, see https://github.com/presidentbeef/brakeman/blob/master/lib/brakeman/checks/check_validation_regex.rb" \
    'validates_format_of' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "validates_format_of" \
    "2_ruby_validates_format_of.txt"
    
fi

#The C and C-derived languages specific stuff
if [ "$DO_C" = "true" ]; then
    
    echo "#Doing C and derived languages"
    
    search "malloc. Rather rare bug, but see issues CVE-2010-0041 and CVE-2010-0042. Uninitialized memory access issues? Could also happen in java/android native code. Also developers should check return codes." \
    'malloc(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'malloc\(' \
    "4_c_malloc.txt"
    
    search "realloc. Rather rare bug, but see issues CVE-2010-0041 and CVE-2010-0042. Uninitialized memory access issues? Could also happen in java/android native code. Also developers should check return codes." \
    'realloc(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'realloc\(' \
    "4_c_realloc.txt"
    
    search "Buffer overflows and format string vulnerable methods: memcpy, memset, strcat --> strlcat, strcpy --> strlcpy, strncat --> strlcat, strncpy --> strlcpy, sprintf --> snprintf, vsprintf --> vsnprintf, gets --> fgets" \
    'memcpy(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'memcpy\(' \
    "2_c_insecure_c_functions_memcpy.txt"
    
    search "Buffer overflows and format string vulnerable methods: memcpy, memset, strcat --> strlcat, strcpy --> strlcpy, strncat --> strlcat, strncpy --> strlcpy, sprintf --> snprintf, vsprintf --> vsnprintf, gets --> fgets" \
    'memset(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'memset\(' \
    "2_c_insecure_c_functions_memset.txt"
    
    search "Buffer overflows and format string vulnerable methods: memcpy, memset, strcat --> strlcat, strcpy --> strlcpy, strncat --> strlcat, strncpy --> strlcpy, sprintf --> snprintf, vsprintf --> vsnprintf, gets --> fgets" \
    'strncat(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'strn?cat\(' \
    "2_c_insecure_c_functions_strcat_strncat.txt"
    
    search "Buffer overflows and format string vulnerable methods: memcpy, memset, strcat --> strlcat, strcpy --> strlcpy, strncat --> strlcat, strncpy --> strlcpy, sprintf --> snprintf, vsprintf --> vsnprintf, gets --> fgets" \
    'strncpy(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'strn?cpy\(' \
    "2_c_insecure_c_functions_strcpy_strncpy.txt"
    
    search "Buffer overflows and format string vulnerable methods: memcpy, memset, strcat --> strlcat, strcpy --> strlcpy, strncat --> strlcat, strncpy --> strlcpy, sprintf --> snprintf, vsprintf --> vsnprintf, gets --> fgets" \
    'snprintf(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'sn?printf\(' \
    "2_c_insecure_c_functions_sprintf_snprintf.txt"
    
    search "Buffer overflows and format string vulnerable methods: memcpy, memset, strcat --> strlcat, strcpy --> strlcpy, strncat --> strlcat, strncpy --> strlcpy, sprintf --> snprintf, vsprintf --> vsnprintf, gets --> fgets" \
    'fnprintf(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'fn?printf\(' \
    "2_c_insecure_c_functions_fprintf_fnprintf.txt"
    
    search "Buffer overflows and format string vulnerable methods: memcpy, memset, strcat --> strlcat, strcpy --> strlcpy, strncat --> strlcat, strncpy --> strlcpy, sprintf --> snprintf, vsprintf --> vsnprintf, gets --> fgets. Additionally the format string should never be simple %s but rather %9s or similar to limit size that is read." \
    'fscanf(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'f?scanf\(' \
    "2_c_insecure_c_functions_fscanf_scanf.txt"
    
    search "Buffer overflows and format string vulnerable methods: memcpy, memset, strcat --> strlcat, strcpy --> strlcpy, strncat --> strlcat, strncpy --> strlcpy, sprintf --> snprintf, vsprintf --> vsnprintf, gets --> fgets" \
    'gets(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'gets\(' \
    "2_c_insecure_c_functions_gets.txt"
    
    search "Random is not a secure random number generator" \
    'random(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'random\(' \
    "2_c_random.txt"
    
fi

if [ "$DO_MALWARE_DETECTION" = "true" ]; then
    
    echo "#Doing malware detection"
    
    search "Viagra search" \
    'viagra' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'viagra' \
    "4_malware_viagra.txt" \
    "-i"
    
    search "Potenzmittel is the German word mostly used for viagra" \
    'potenzmittel' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'potenzmittel' \
    "4_malware_potenzmittel.txt" \
    "-i"
    
    search "Pharmacy" \
    'pharmacy' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'pharmacy' \
    "4_malware_pharmacy.txt" \
    "-i"
    
    search "Drug" \
    'drug' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'drug' \
    "4_malware_drug.txt" \
    "-i"
fi

#The crypto and credentials specific stuff (language agnostic)
if [ "$DO_CRYPTO_AND_CREDENTIALS" = "true" ]; then
    
    echo "#Doing crypto and credentials"
    
    search "Crypt (the method itself) can be dangerous, also matches any calls to decrypt(, encrypt( or whatevercrypt(, which is desired" \
    'crypt(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'crypt\(' \
    "3_cryptocred_crypt_call.txt" \
    "-i"
    
    search "Rot32 is really really bad obfuscation and has nothing to do with crypto." \
    'ROT32' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'ROT32' \
    "3_cryptocred_ciphers_rot32.txt" \
    "-i"
    
    search "RC2 cipher. Security depends heavily on usage and what is secured." \
    'RC2' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'RC2' \
    "3_cryptocred_ciphers_rc2.txt" \
    "-i"
    
    search "RC4 cipher. Security depends heavily on usage and what is secured." \
    'RC4' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'RC4' \
    "3_cryptocred_ciphers_rc4.txt"
    
    search "CRC32 is a checksum algorithm. Security depends heavily on usage and what is secured." \
    'CRC32' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'CRC32' \
    "3_cryptocred_ciphers_crc32.txt" \
    "-i"
    
    search "DES cipher. Security depends heavily on usage and what is secured." \
    'DES' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'DES' \
    "3_cryptocred_ciphers_des.txt"
    
    search "MD2. Security depends heavily on usage and what is secured." \
    'MD2' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'MD2' \
    "3_cryptocred_ciphers_md2.txt"
    
    search "MD5. Security depends heavily on usage and what is secured." \
    'MD5' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'MD5' \
    "3_cryptocred_ciphers_md5.txt"
    
    search "SHA1. Security depends heavily on usage and what is secured." \
    'SHA1' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'SHA-?1' \
    "3_cryptocred_ciphers_sha1_uppercase.txt"
    
    search "SHA1. Security depends heavily on usage and what is secured." \
    'sha1' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'sha-?1' \
    "3_cryptocred_ciphers_sha1_lowercase.txt"
    
    search "SHA256. Security depends heavily on usage and what is secured." \
    'SHA256' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'SHA-?256' \
    "3_cryptocred_ciphers_sha256.txt" \
    "-i"
    
    search "SHA256. Security depends heavily on usage and what is secured." \
    'SHA512' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'SHA-?512' \
    "3_cryptocred_ciphers_sha512.txt" \
    "-i"
    
    search "NTLM. Security depends heavily on usage and what is secured." \
    'NTLM' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'NTLM' \
    "3_cryptocred_ciphers_ntlm.txt"
    
    search "Kerberos. Security depends heavily on usage and what is secured." \
    'Kerberos' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'kerberos' \
    "3_cryptocred_ciphers_kerberos.txt" \
    "-i"
    
    #take care with the next regex, ! has a special meaning in double quoted strings but not in single quoted
    search "Hash" \
    'hash_value' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'hash(?!(table|map|set|code))' \
    "5_cryptocred_hash.txt" \
    "-i"
    
    search 'Find *nix passwd or shadow files.' \
    '_xcsbuildagent:*:239:239:Xcode Server Build Agent:/var/empty:/usr/bin/false' \
    '/Users/eh2pasz/workspace/ios/CCB/CCB/Classes/CBSaver.h:23:46: note: passing argument to parameter "name" here^M+ (NSString *)loadStringWithName:(NSString *)name; 1b:ee:24:46:0c:17:' \
    "[^:]{3,$WILDCARD_SHORT}:[^:]{1,$WILDCARD_LONG}:\d{0,$WILDCARD_SHORT}:\d{0,$WILDCARD_SHORT}:[^:]{0,$WILDCARD_LONG}:[^:]{0,$WILDCARD_LONG}:[^:]*$" \
    "1_cryptocred_passwd_or_shadow_files.txt" \
    "-i"
    
    search "Encryption key and variants of it" \
    'encrypt the key' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "encrypt.{0,$WILDCARD_SHORT}key" \
    "2_cryptocred_encryption_key.txt" \
    "-i"
    
    search "Sources of entropy: /dev/random and /dev/urandom" \
    '/dev/urandom' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "/dev/u?random" \
    "2_cryptocred_dev_random.txt"
    
    search "Narrow search for certificate and keys specifics of base64 encoded format" \
    'BEGIN CERTIFICATE' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'BEGIN CERTIFICATE' \
    "2_cryptocred_certificates_and_keys_narrow_begin-certificate.txt"
    
    search "Narrow search for certificate and keys specifics of base64 encoded format" \
    'PRIVATE KEY' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'PRIVATE KEY' \
    "1_cryptocred_certificates_and_keys_narrow_private-key.txt"
    
    search "Narrow search for certificate and keys specifics of base64 encoded format" \
    'PUBLIC KEY' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'PUBLIC KEY' \
    "2_cryptocred_certificates_and_keys_narrow_public-key.txt"
    
    search "Wide search for certificate and keys specifics of base64 encoded format" \
    'begin certificate' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "BEGIN.{0,$WILDCARD_SHORT}CERTIFICATE" \
    "4_cryptocred_certificates_and_keys_wide_begin-certificate.txt" \
    "-i"
    
    search "Wide search for certificate and keys specifics of base64 encoded format" \
    'private key' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "PRIVATE.{0,$WILDCARD_SHORT}KEY" \
    "4_cryptocred_certificates_and_keys_wide_private-key.txt" \
    "-i"
    
    search "Wide search for certificate and keys specifics of base64 encoded format" \
    'public key' \
    'public String getBlaKey' \
    "PUBLIC.{0,$WILDCARD_SHORT}KEY" \
    "4_cryptocred_certificates_and_keys_wide_public-key.txt" \
    "-i"
    
    search "Salt for a hashing algorithm?" \
    'Salt or salt' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "[Ss]alt" \
    "5_cryptocred_salt1.txt"
    
    search "Salt for a hashing algorithm?" \
    'SALT' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "SALT" \
    "5_cryptocred_salt2.txt"
    
    search "Hexdigest" \
    'hex-digest' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "hex.?digest" \
    "5_cryptocred_hexdigest.txt" \
    "-i"
    
    search "Default password" \
    'default-password' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'default.?password' \
    "2_cryptocred_default_password.txt" \
    "-i"
    
    search "Password and variants of it" \
    'pass-word or passwd' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'pass.?wo?r?d' \
    "3_cryptocred_password.txt" \
    "-i"
    
    search "PWD abbrevation for password" \
    'PWD' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'PWD' \
    "4_cryptocred_pwd_uppercase.txt"
    
    search "pwd abbrevation for password" \
    'pwd' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'pwd' \
    "4_cryptocred_pwd_lowercase.txt"
    
    search "Pwd abbrevation for password" \
    'Pwd' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Pwd' \
    "4_cryptocred_pwd_capitalcase.txt"
    
    search "Credentials. Included everything 'creden' because some programers write credencials instead of credentials and such things." \
    'credentials' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'creden' \
    "3_cryptocred_credentials.txt" \
    "-i"
    
    search "Passcode and variants of it" \
    'passcode' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "pass.?code" \
    "3_cryptocred_passcode.txt" \
    "-i"
    
    search "Passphrase and variants of it" \
    'passphrase' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "pass.?phrase" \
    "3_cryptocred_passphrase.txt" \
    "-i"
    
    search "Secret and variants of it" \
    'secret' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "se?3?cre?3?t" \
    "3_cryptocred_secret.txt" \
    "-i"
    
    search "PIN code and variants of it" \
    'pin code' \
    'mapping between error codes, pin.hashCode' \
    "pin.{0,$WILDCARD_SHORT}code" \
    "2_cryptocred_pin_code.txt" \
    "-i"
    
    search "Proxy-Authorization" \
    'ProxyAuthorisation' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Proxy.?Authoris?z?ation' \
    "4_cryptocred_proxy-authorization.txt" \
    "-i"
    
    search "Authorization" \
    'Authorisation' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Authori[sz]ation' \
    "4_cryptocred_authorization.txt" \
    "-i"
    
    search "Authentication" \
    'Authentication' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Authentication' \
    "4_cryptocred_authentication.txt" \
    "-i"
    
    search "SSL usage with requireSSL" \
    'requireSSL' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "require.{0,$WILDCARD_SHORT}SSL" \
    "3_cryptocred_ssl_usage_require-ssl.txt" \
    "-i"
    
    search "SSL usage with useSSL" \
    'use ssl' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "use.{0,$WILDCARD_SHORT}SSL" \
    "3_cryptocred_ssl_usage_use-ssl.txt" \
    "-i"
    
    search "TLS usage with require TLS" \
    'require TLS' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "require.{0,$WILDCARD_SHORT}TLS" \
    "3_cryptocred_tls_usage_require-tls.txt" \
    "-i"
    
    search "TLS usage with use TLS" \
    'use TLS' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "use.{0,$WILDCARD_SHORT}TLS" \
    "3_cryptocred_tls_usage_use-tls.txt" \
    "-i"
    
fi

#Very general stuff (language agnostic)
if [ "$DO_GENERAL" = "true" ]; then
    
    echo "#Doing general"
    
    search "A generic templating pattern that is used in HTML generation of Java (JSP), Ruby and client-side JavaScript libraries." \
    'In Java <%=bean.getName()%> or in ruby <%= parameter[:value] %>' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '<%=' \
    "2_general_html_templating.txt"
    
    search "Superuser. Sometimes the root user of *nix is referenced, sometimes it is about root detection on mobile phones (e.g. Android Superuser.apk app detection)" \
    'super_user' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "super.{0,$WILDCARD_SHORT}user" \
    "2_general_superuser.txt" \
    "-i"
    
    search "Su binary" \
    'sudo binary' \
    'suite.api.java.rql.construct.Binary, super(name, contentType, binary' \
    "su.{0,$WILDCARD_SHORT}binary" \
    "2_general_su-binary.txt" \
    "-i"
    
    search "sudo" \
    'sudo make me a sandwich' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "sudo\s" \
    "2_general_sudo.txt"
    
    search "Denying is often used for filtering, etc." \
    'deny' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "[Dd]eny" \
    "4_general_deny.txt"
    
    search "Exec mostly means executing on OS." \
    'runTime.exec("echo "+unsanitized_input);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "exec\s{0,$WILDCARD_SHORT}\(" \
    "3_general_exec_narrow.txt"
    
    search "Exec mostly means executing on OS." \
    'runTime.exec("echo "+unsanitized_input);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "exec" \
    "4_general_exec_wide.txt"
    
    search "Eval mostly means evaluating commands." \
    'eval (' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "eval\s{0,$WILDCARD_SHORT}\(" \
    "3_general_eval_narrow.txt"
    
    search "Eval mostly means evaluating commands." \
    'eval' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "eval" \
    "4_general_eval_wide.txt"
    
    search "Syscall: Command execution?" \
    'syscall(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "sys.?call\s{0,$WILDCARD_SHORT}\(" \
    "3_general_syscall_narrow.txt" \
    "-i"
    
    search "Syscall: Command execution?" \
    'syscall' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "sys.?call" \
    "4_general_syscall_wide.txt" \
    "-i"
    
    search "system: Command execution?" \
    'system(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "system\s{0,$WILDCARD_SHORT}\(" \
    "3_general_system_narrow.txt" \
    "-i"
    
    search "system: Command execution?" \
    'system' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "system" \
    "4_general_system_wide.txt" \
    "-i"
    
    search "pipeline: Command execution?" \
    'pipeline(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "pipeline\s{0,$WILDCARD_SHORT}\(" \
    "3_general_pipeline_narrow.txt" \
    "-i"
    
    search "pipeline: Command execution?" \
    'pipeline' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "pipeline" \
    "4_general_pipeline_wide.txt" \
    "-i"
    
    search "popen: Command execution?" \
    'popen(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "popen\s{0,$WILDCARD_SHORT}\(" \
    "3_general_popen_narrow.txt" \
    "-i"
    
    search "popen: Command execution?" \
    'popen' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "popen" \
    "4_general_popen_wide.txt" \
    "-i"
    
    search "spawn: Command execution?" \
    'spawn(' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "spawn\s{0,$WILDCARD_SHORT}\(" \
    "3_general_spawn_narrow.txt" \
    "-i"
    
    search "spawn: Command execution?" \
    'spawn' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "spawn" \
    "4_general_spawn_wide.txt" \
    "-i"
    
    search "chgrp: Change group command" \
    'chgrp' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "chgrp" \
    "4_general_chgrp.txt" \
    "-i"
    
    search "chown: Change owner command" \
    'chown' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "chown" \
    "4_general_chown.txt" \
    "-i"
    
    search "chmod: Change mode (permissions) command" \
    'chmod' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "chmod" \
    "4_general_chmod.txt" \
    "-i"
    
    search "Session timeouts should be reasonable short for things like sessions for web logins but can also lead to denial of service conditions in other cases." \
    'session-timeout' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'session-?\s?time-?\s?out' \
    "3_general_session_timeout.txt" \
    "-i"
    
    search "Timeout. Whatever timeout this might be, that might be interesting." \
    'timeout' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'time-?\s?out' \
    "4_general_session_timeout.txt" \
    "-i"
    
    search "General setcookie command used in HTTP, important to see HTTPonly/secure flags, path setting, etc." \
    'setcookie' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'setcookie' \
    "3_general_setcookie.txt" \
    "-i"
    
    search "General serialisation code, can lead to command execution" \
    'serialise' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'seriali[sz]e' \
    "3_general_serialise.txt" \
    "-i"
    
    search "Relative paths. May allow an attacker to put something early in the search path (if parts are user supplied input) and overwrite behavior" \
    '../../' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\./' \
    "4_general_relative_paths.txt" \
    "-i"
    
    search "Search for the word credit card" \
    'credit-card' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'credit.?card' \
    "3_general_creditcard.txt" \
    "-i"
    
    search "Update code and general update strategy weaknesses" \
    'Update' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'update' \
    "5_general_update.txt" \
    "-i"
    
    search "Backup code and general backup strategy weaknesses" \
    'Backup' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'backup' \
    "5_general_backup.txt" \
    "-i"
    
    search "Kernel. A reference to something low level in a Kernel?" \
    'Kernel' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'Kernel' \
    "4_general_kernel.txt" \
    "-i"
    
    #Take care with the following regex, @ has a special meaning in double quoted strings, but not in single quoted strings
    search "Email addresses" \
    'example-email_address-@example-domain.com' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}\b' \
    "5_general_email.txt" \
    "-i"
     
    search "TODOs, unfinished and insecure things?" \
    'Todo:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '[Tt]odo' \
    "5_general_todo_capital_and_lower.txt"
    
    search "TODOs, unfinished and insecure things?" \
    'TODO:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'TODO' \
    "5_general_todo_uppercase.txt"
    
    search "Workarounds, maybe they work around security?" \
    'workaround: ' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'workaround' \
    "5_general_workaround.txt" \
    "-i"
    
    search "Hack. Developers sometimes hack something around security." \
    'hack' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'hack' \
    "4_general_hack.txt" \
    "-i"
    
    search "Crack. Sounds suspicious." \
    'crack' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'crack' \
    "4_general_crack.txt" \
    "-i"
    
    search "Trick. Sounds suspicious." \
    'trick' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'trick' \
    "4_general_trick.txt" \
    "-i"
    
    search "Exploit and variants of it. Sounds suspicious." \
    'exploit' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'xploit' \
    "4_general_exploit.txt" \
    "-i"
    
    search "Bypass. Sounds suspicious, what do they bypass exactly?" \
    'bypass' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'bypass' \
    "4_general_bypass.txt" \
    "-i"
    
    search "Backdoor. Sounds suspicious, why would anyone ever use this word?" \
    'back-door' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "back.{0,$WILDCARD_SHORT}door" \
    "4_general_backdoor.txt" \
    "-i"
    
    search "Backd00r. Sounds suspicious, why would anyone ever use this word?" \
    'back-d00r' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "back.{0,$WILDCARD_SHORT}d00r" \
    "4_general_backd00r.txt" \
    "-i"
    
    search "Fake. Sounds suspicious." \
    'fake:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'fake' \
    "4_general_fake.txt" \
    "-i"
    
    #Take care with the following regex, @ has a special meaning in double quoted strings, but not in single quoted strings
    search "URIs with authentication information specified as ://username:password@example.org" \
    'http://username:password@example.com' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "://.{1,$WILDCARD_SHORT}:.{1,$WILDCARD_SHORT}@" \
    "1_general_uris_auth_info_narrow.txt" \
    "-i"
    
    #Take care with the following regex, @ has a special meaning in double quoted strings, but not in single quoted strings
    search "URIs with authentication information specified as username:password@example.org" \
    'username:password@example.com' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    ".{1,$WILDCARD_SHORT}:.{1,$WILDCARD_SHORT}@" \
    "2_general_uris_auth_info_wide.txt" \
    "-i"
    
    search "All HTTPS URIs" \
    'https://example.com' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'https://' \
    "4_general_https_urls.txt" \
    "-i"
    
    search "All HTTP URIs" \
    'http://example.com' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'http://' \
    "4_general_http_urls.txt" \
    "-i"
    
    search "Non-SSL URIs ftp" \
    'ftp://example.com' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'ftp://' \
    "3_general_non_ssl_uris_ftp.txt" \
    "-i"
    
    search "Non-SSL URIs socket" \
    'socket://192.168.0.1:3000' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'socket://' \
    "3_general_non_ssl_uris_socket.txt" \
    "-i"
    
    search "Non-SSL URIs imap" \
    'imap://example.com' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'imap://' \
    "3_general_non_ssl_uris_imap.txt" \
    "-i"
    
    search "file URIs" \
    'file://c/example.txt' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'file://' \
    "3_general_non_ssl_uris_file.txt" \
    "-i"
    
    search "jdbc URIs" \
    'jdbc:mysql://localhost/test?password=ABC' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'jdbc:' \
    "3_general_jdbc_uri.txt" \
    "-i"
    
    search "Hidden things, for example hidden HTML fields" \
    'hidden:' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'hidden' \
    "4_general_hidden.txt" \
    "-i"
    
    search "WSDL defines web services" \
    'example.wsdl' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'wsdl' \
    "3_general_wsdl.txt" \
    "-i"
    
    search "Directory listing, usually a bad idea in web servers." \
    'directory-listing' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "directory.{0,$WILDCARD_SHORT}listing" \
    "3_general_directory_listing.txt" \
    "-i"
    
    search "SQL injection and variants of it. Sometimes refered in comments or variable names for code that should prevent it. If you find something interesting that is used for prevention in a framework, you might want to add another grep for that in this script." \
    'sql-injection' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "sql.{0,$WILDCARD_SHORT}injection" \
    "2_general_sql_injection.txt" \
    "-i"
    
    search "XSS. Sometimes refered in comments or variable names for code that should prevent it. If you find something interesting that is used for prevention in a framework, you might want to add another grep for that in this script." \
    'XSS' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'xss' \
    "2_general_xss.txt" \
    "-i"
    
    search "Clickjacking and variants of it. Sometimes refered in comments or variable names for code that should prevent it. If you find something interesting that is used for prevention in a framework, you might want to add another grep for that in this script." \
    'click-jacking' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "click.{0,$WILDCARD_SHORT}jacking" \
    "2_general_hacking_techniques_clickjacking.txt" \
    "-i"
    
    search "XSRF/CSRF and variants of it. Sometimes refered in comments or variable names for code that should prevent it. If you find something interesting that is used for prevention in a framework, you might want to add another grep for that in this script." \
    'xsrf' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "xsrf" \
    "2_general_hacking_techniques_xsrf.txt" \
    "-i"
    
    search "XSRF/CSRF and variants of it. Sometimes refered in comments or variable names for code that should prevent it. If you find something interesting that is used for prevention in a framework, you might want to add another grep for that in this script." \
    'csrf' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "csrf" \
    "2_general_hacking_techniques_csrf.txt" \
    "-i"
    
    search "Buffer overflow and variants of it. Sometimes refered in comments or variable names for code that should prevent it. If you find something interesting that is used for prevention in a framework, you might want to add another grep for that in this script." \
    'buffer-overflow' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "buffer.{0,$WILDCARD_SHORT}overflow" \
    "2_general_hacking_techniques_buffer-overflow.txt" \
    "-i"
    
    search "Integer overflow and variants of it. Sometimes refered in comments or variable names for code that should prevent it. If you find something interesting that is used for prevention in a framework, you might want to add another grep for that in this script." \
    'integer-overflow' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "integer.{0,$WILDCARD_SHORT}overflow" \
    "2_general_hacking_techniques_integer-overflow.txt" \
    "-i"
    
    search "Obfuscation and variants of it. Might be interesting code where the obfuscation is done. If you find something interesting that is used for obfuscation in a framework, you might want to add another grep for that in this script." \
    'obfuscation' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "obfuscat" \
    "2_general_obfuscation.txt" \
    "-i"
    
    #take care with the following regex, backticks have to be escaped
    search "Everything between backticks, because in Perl and Shell scirpting (eg. cgi-scripts) these are system execs." \
    '`basename file-var`' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\`.{2,$WILDCARD_LONG}\`" \
    "3_general_backticks.txt"\
    "-i"
    
    search "SQL SELECT statement" \
    'SELECT EXAMPLE, ABC, DEF FROM TABLE' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "SELECT\s.{0,$WILDCARD_LONG}FROM" \
    "3_general_sql_select.txt" \
    "-i"
    
    search "SQL INSERT statement" \
    'INSERT INTO TABLE example VALUES(123);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "INSERT.{0,$WILDCARD_SHORT}INTO" \
    "3_general_sql_insert.txt" \
    "-i"
    
    search "SQL DELETE statement" \
    'DELETE COLUMN WHERE 1=1' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "DELETE.{0,$WILDCARD_LONG}WHERE" \
    "3_general_sql_delete.txt" \
    "-i"
    
    search "SQL SQLITE" \
    'sqlite' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "sqlite" \
    "4_general_sql_sqlite.txt" \
    "-i"
    
    search "Base64 encoded data (that is more than 6 bytes long). This regex won't detect a base64 encoded value over several lines..." \
    'YWJj YScqKyo6LV/Dpw==' \
    '/target/ //JQLite - the following ones shouldnt be an issue anymore as we require more than 6 bytes: done echo else gen/ ////' \
    '(?:[A-Za-z0-9+/]{4})+(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{4})' \
    "2_general_base64_content.txt"
    #case sensitive, the regex is insensitive anyway
    
    search "Base64 URL-safe encoded data (that is more than 6 bytes long). To get from URL-safe base64 to regular base64 you need .replace('-','+').replace('_','/'). This regex won't detect a base64 encoded value over several lines..." \
    'YScqKyo6LV_Dpw==' \
    '/target/ //JQLite - the following ones shouldnt be an issue anymore as we require more than 6 bytes: done echo else gen/ ////' \
    '(?:[A-Za-z0-9_-]{4})+(?:[A-Za-z0-9_-]{2}==|[A-Za-z0-9_-]{3}=|[A-Za-z0-9_-]{4})' \
    "2_general_base64_urlsafe.txt"
    #case sensitive, the regex is insensitive anyway
    
    search "Base64 as a word used" \
    'Base64' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'base64' \
    "2_general_base64_word.txt" \
    "-i"
    
    search "GPL violation? Not security related, but your customer might be happy to know such stuff" \
    'GNU GPL' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'GNU\sGPL' \
    "5_general_gpl1.txt" \
    "-i"
    
    search "GPL violation? Not security related, but your customer might be happy to know such stuff" \
    'GPLv2' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'GPLv2' \
    "5_general_gpl2.txt" \
    "-i"
    
    search "GPL violation? Not security related, but your customer might be happy to know such stuff" \
    'GPLv3' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'GPLv3' \
    "5_general_gpl3.txt" \
    "-i"
    
    search "GPL violation? Not security related, but your customer might be happy to know such stuff" \
    'GPL Version' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'GPL\sVersion' \
    "5_general_gpl4.txt" \
    "-i"
    
    search "GPL violation? Not security related, but your customer might be happy to know such stuff" \
    'General Public License' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'General\sPublic\sLicense' \
    "5_general_gpl5.txt" \
    "-i"
    
    search "Stupid: Swear words are often used when things don't work as intended by the developer." \
    'Stupid!' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'stupid' \
    "3_general_swear_stupid.txt" \
    "-i"
    
    search "Fuck: Swear words are often used when things don't work as intended by the developer. X-)" \
    'Fuck!' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'fuck' \
    "3_general_swear_fuck.txt" \
    "-i"
    
    search "Shit and bullshit: Swear words are often used when things don't work as intended by the developer." \
    'Shit!' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'shit' \
    "3_general_swear_shit.txt" \
    "-i"
    
    search "Crap: Swear words are often used when things don't work as intended by the developer." \
    'Crap!' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'crap' \
    "3_general_swear_crap.txt" \
    "-i"
    
    #IP-Adresses
    #\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.
    #  (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.
    #  (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.
    #  (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b
    search "IP addresses" \
    '192.168.0.1 10.0.0.1' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)' \
    "3_general_ip-addresses.txt" \
    "-i"

    search "Referer is only used for the HTTP Referer usually, it can be specified by the attacker" \
    'referer' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    'referer' \
    "3_general_referer.txt" \
    "-i"
    
    search "Generic search for SQL injection, FROM and WHERE being SQL keywords and + meaning string concatenation" \
    'q = "SELECT * from USERS where NAME=" + user;' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "from\s.{0,$WILDCARD_LONG}\swhere\s.{0,$WILDCARD_LONG}" \
    "3_general_sqli_generic.txt" \
    "-i"
    
    search "A form of query often used for LDAP, should be checked if it doesn't lead to LDAP injection and/or DoS" \
    'String ldap_query = "(&(param=user)(name=" + name_unsanitized + "))";' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "\(&\(.{0,$WILDCARD_SHORT}=" \
    "3_general_ldap_generic.txt" \
    "-i"
    
    search "Generic sleep call, if server side this could block thread/process and therefore enable to easily do Denial of Service attacks" \
    'sleep(2);' \
    'FALSE_POSITIVES_EXAMPLE_PLACEHOLDER' \
    "sleep" \
    "3_general_sleep_generic.txt" \
    "-i"
    
fi


if [ "$BACKGROUND" = "true" ]; then
    #Let's wait until all jobs are done
    for job in $(jobs -p)
    do
        wait $job
    done
fi
echo ""
echo "Done grep. Results in $TARGET."
echo "It's optimised to be viewed with 'less -R $TARGET/*' and then you can hop from one file to the next with :n"
echo "and :p. Maybe you want to add the -S option of less for very long lines. The cat command works fine too. "
echo "If you want another editor you should probably remove --color=always from the options"
echo ""
echo "Have a grepy day."

###
#END CODE SECTION
###