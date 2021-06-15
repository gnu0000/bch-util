
Fixing Trivox text strings.

This directory contains utilities for examining and fixing up Uifield/Langui 
and question/questiontext text strings.

Manifest:
   Readme.txt ............ This file

   UifieldFixFirst.pl .... Initial utility for cleaning up Uifield/Langui text
   UifieldFixLast.pl ..... Final utility for cleaning up Uifield/Langui text
   UifieldView.pl ........ Utility for examining Uifield/Langui text

   QuestionFixFirst.pl ... Initial utility for cleaning up question/questiontext text
   QuestionFixMiddle.pl .. Middle utility for cleaning up question/questiontext text
   QuestionFixLast.pl .... Final utility for cleaning up question/questiontext text
   QuestionView.pl ....... Utility for examining question/questiontext text

   qt/* .................. Web based editors for Langui and questiontext text strings.
   lib/* ................. Support for the scripts


Each utility has a description block, and a commandline help section below:
===============================================================================

# UifieldFixFirst.pl 
#
# This utility is for cleaning up Uifield/langui text
#
# This utility is the first step in cleaning up the uifields when adding a 
#  new foreign language. 
#
# Specifically, this utility strips various tags and replaces (varname) in 
#  the foreign text with the corresponding <var>varname</var> from the 
#  english text.
#
# As a secondary feature, this utility can also be used to dump what the
#  changes would be (using -test and -debug options)
#
# Commandline help:
-------------------------------------------------------------------------------
UifieldFixFirst.pl - Initial utility for cleaning up uifields

USAGE: UifieldFixFirst.pl [options]

WHERE: [options] is one or more of:
   -language=spanish .. Pick which language were cleaning (spanish|portuguese)
   -test .............. run, but dont actually update the database
   -doit .............. run, actually update the database
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)
   -debug.............. Use with -test to dump changes

EXAMPLES: 
   UifieldFixFirst.pl -test
   UifieldFixFirst.pl -doit -language=spanish
   UifieldFixFirst.pl -doit -lang=portuguese
   UifieldFixFirst.pl -test -host=test.me.com -username=bubba -password=password

NOTES:
   The following modification are applied to all active langui.value fields
   in the specified language:

   - <div> tags are stripped   
   - <span> tags are stripped   
   - <p> tags are stripped   
   - &nbsp; tags are replaced with a space
   - excessive <br /> tags are stripped (at most 2 consecutive)
   - Leading / Trailing space is trimmed
   - If the text has a '(first name)' or one of a hundred permutations
      like it, and if the english version of the text has a <var> tag
      that is named firstname or childfirstname or something like it,
      then the '(first name)' is replaced with the var tag
   - If the text has a '(ident)', and if the english version of the 
      text has a <var>ident</var> tag, then the '(ident)' is replaced 
      with the var tag
===============================================================================

# UifieldFixLast.pl
#
# This utility is for cleaning up Uifield/langui text
#
# This utility is the last step in cleaning up the uifields when adding a 
#  new foreign language. 
#
# Specifically, this utility:
#  -Looks for and replaces UTF-8 bytecode sequences and replaces them with html
#    entities.
#
#  -Looks for certain html entities (&amp; &lt; &gt;) and replaces them with the
#    character. (This is necessary because the text sometimes contains template code)
#
#  As a secondary feature, this utility can be used to dump the hex codes of
#    the non ascii characters used in the text
#
# See the bottom of this file, or run this script with no options to
#  get usage information.
#
# See the README for more information.
#
# Commandline help:
-------------------------------------------------------------------------------
UifieldFixLast.pl - Final utility for cleaning up uifields

USAGE: UifieldFixLast.pl [options]

WHERE: [options] is one or more of:
   -language=spanish .. Pick language to clean (english|spanish|portuguese)
   -test .............. Run, but dont actually update the database
   -doit .............. Run, actually update the database
   -id=languiid ....... Only process this record
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)
   -debug ............. (with -test) show string changes
   -debug2 ............ (with -test) show utf-8 char bytes

EXAMPLES:
   UifieldFixLast.pl -lang=spanish -test
   UifieldFixLast.pl -lang=spanish -test -debug
   UifieldFixLast.pl -lang=spanish -doit

NOTES:
   The following modification are applied to all active langui.value fields
   in the specified language:
   
   - Known UTF-8 char codes are replaced with html entities.
   - Certain html entities (&amp; &lt; &gt;) are replaced with the char

   - this utility can be used to dump the hex codes of the non ascii 
     characters used in the text (using -test and -debug)
===============================================================================

# UifieldView.pl 
#
# This utility is for examining Uifield/langui text
#
# This utility is usefull for determining what problems exist, what 
#  foreign fields are missing, what <var> names are present, and generating
#  indexes of uifields that can be used with the web page editor.
#
# This utility can generate html as well as text.  This can be usefull for
#  detecting broken tags, as all following html will likely be screwed up.
#
# See the bottom of this file, or run this script with no options to
#  get usage information.
#
# See the README for more information.
#
# Some examples:
#
#   Generate a html page of all the uifields:
#
#     UifieldView.pl -e -html > foo.html
#
#   Generate a html page of all the uifields and the protugeuse translations:
#
#     UifieldView.pl -language=portuguese -e -f -html > foo.html
#
#   Display all uifields (and associated langui) that have both english
#   and spanish text:
#
#     UifieldView.pl -language=spanish -e -f
#
#   Display all uifields (and associated langui) that have both english
#   and spanish text, and that have the "<" char encoded as an html entity
#   in ther spanish text:
#
#     UifieldView.pl -language=spanish -e -f -ftext="&lt;"
#
#   Create a web page containing all uifields (and associated langui) that 
#    have <var>'s in the english text, but dont have <var>'s in the spanish text
#
#     UifieldView.pl -language=spanish -e -f -ve -vnf -html > foo.html
#
# Commandline help:
-------------------------------------------------------------------------------
UifieldView.pl - Utility for displaying TriVox uifield string data in
                 text or html

USAGE: tvuifields.pl [options]

WHERE: [options] is one or more of:
    -language=9999 . Specify language in addition to english (spanish)
    -all ........... Show all uifields
    -e ............. Exclude all but uifields that have english text
    -ne ............ Exclude all but uifields that dont have english text
    -f ............. Exclude all but uifields that have foreign text
    -nf ............ Exclude all but uifields that dont have foreign text
    -v ............. Exclude all but uifields that have vars
    -nv ............ Exclude all but uifields that dont have vars
    -ve ............ Exclude all but uifields that have english text vars
    -vf ............ Exclude all but uifields that have foreign text vars
    -vne ........... Exclude all but uifields that dont have english text vars
    -vnf ........... Exclude all but uifields that dont have foreign text vars
    -vars .......... Include vars and parens
    -etext=str ..... Exclude all but uifields that have this english text
    -ftext=str ..... Exclude all but uifields that have this foreign text
    -id ............ Exclude all but uifields with this uifield id
    -eid ........... Exclude all but uifields with this langui id
    -fid ........... Exclude all but uifields with this langui id
    -host=foo ...... Set the mysqlhost (localhost)
    -username=foo .. Set the mysqlusername (avocate)
    -password=foo .. Set the mysqlpassword (****************)
    -html .......... Generate html (default is text)

EXAMPLES: 
    UifieldView.pl -lang=portuguese -all
    UifieldView.pl -e -f -v -html
    UifieldView.pl -host=trivox-db.cymcwhoejtz8.us-east-1.rds.amazonaws.com -all
    UifieldView.pl -language=spanish -e -f -ftext="&lt;"

NOTES:
    -language can be set to:
       spanish or 5912 for Spanish
       portuguese or 5265 for Portuguese
===============================================================================

# QuestionFixFirst.pl 
#
# This utility is for cleaning up question/questiontext text
#
# This utility is the first step in cleaning up the questiontext when adding a 
#  new foreign language. 
#
# Specifically, this utility strips various tags and replaces (varname) in 
#  the foreign text with the corresponding <var>varname</var> from the 
#  english text.
#
# See the bottom of this file, or run this script with no options to
#  get usage information.
#
# See the README for more information.
#
# Commandline help:
-------------------------------------------------------------------------------
QuestionFixFirst.pl - Initial utility for cleaning up questiontext

USAGE: QuestionFixFirst.pl [options]

WHERE: [options] is one or more of:
   -language=spanish .. Pick which language were cleaning (spanish|portuguese)
   -test .............. run, but dont actually update the database
   -doit .............. run, actually update the database
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)
   -debug.............. Use with -test to dump changes

EXAMPLES: 
   QuestionFixFirst.pl -test
   QuestionFixFirst.pl -doit -language=spanish
   QuestionFixFirst.pl -doit -lang=portuguese
   QuestionFixFirst.pl -test -host=test.me.com -user=bubba -pass=password

NOTES:
   The following modification are applied to all active questiontext.text 
   fields in the specified language:

   - <div> tags are stripped   
   - <span> tags are stripped   
   - <p> tags are stripped   
   - &nbsp; tags are replaced with a space
   - excessive <br /> tags are stripped (at most 2 consecutive)
   - Leading / Trailing space is trimmed
   - If the text has a '(first name)' or one of a hundred permutations
      like it, and if the english version of the text has a <var> tag
      that is named firstname or childfirstname or something like it,
      then the '(first name)' is replaced with the var tag
   - If the text has a '(ident)', and if the english version of the 
      text has a <var>ident</var> tag, then the '(ident)' is replaced 
      with the var tag
===============================================================================

# QuestionFixMiddle.pl
# 
# This utility is for cleaning up question/questiontext text
# 
# This utility is a middle step in cleaning up the questions when adding a 
#  new foreign language. 
#
# This utility essentially provides the same functionality as the editquestiontext
#  web page utility, with the important distinction that you are working
#  with the raw text.  So basically, you want to use the web page editor to
#  verify and edit questions generally, but there are still some fixups that
#  require this utility.  In particular, The web editors will translate the < > 
#  and & chars to html entities. While theis is what we want 99% of the time,
#  some strings contain ftl code snippets or tags imbedded in strings 
#  intentionally, and you will need this utility to fix them.  Also this util
#  allows you to do search/replace in your editor which can save time.
#
# Specifically, this utility:
#  - Dumps Questions in an editable file. Each question contains the 
#    english, the foreign, and newtext (which is a copy of foreign).
# 
#  - The developer (meaning you), can then edit the file and change
#    whichever newtext entries need editing
# 
#  - The utility can then load the file, and will change the foreign 
#    entries to newtext whenever it finds that you made a change.
# 
#  - There are many filtering options, so you can subset your edit files
#    to certain classes of problems that need certain edit approaches.
# 
# See the bottom of this file, or run this script with no options to
#  get usage information.
#
# See the README for more information.
#
# Commandline help:
-------------------------------------------------------------------------------
QuestionFixMiddle.pl - Utility for cleaning up the foreign QuestionText

USAGE: QuestionFixMiddle.pl [options] patchfile

WHERE: [options] is one or more of:
    -gen ............. Generate a patch file.
    -load ............ Load a patch file, updating the db.
    -test ............ Load a patch file, but dont update the db.
    -language=5912 ... Specify language to gen or load (5912 is default).

Additional options for -gen:
    -e ............... Exclude all but questions that have english text
    -ne .............. Exclude all but questions that dont have english text
    -s ............... Exclude all but questions that have spanish text
    -ns .............. Exclude all but questions that dont have spanish text
    -v ............... Exclude all but questions that have vars
    -nv .............. Exclude all but questions that dont have vars
    -ve .............. Exclude all but questions that have english text vars
    -vne ............. Exclude all but questions that dont have english text vars
    -vs .............. Exclude all but questions that have spanish text vars
    -vns ............. Exclude all but questions that dont have spanish text vars
    -etext=str ....... Exclude all but questions that have this english text
    -stext=str ....... Exclude all but questions that have this spanish text
    -id .............. Exclude all but questions with this question id
    -eid ............. Exclude all but questions with this questiontext id
    -sid ............. Exclude all but questions with this questiontext id

    patchfile is the name of the input/output file.

NOTES:
   1> Generate a patchfile
   
      QuestionFixMiddle.pl -gen patch.txt

      This generates a file containing all questions that have 
      questiontext in both english and spanish (or whichever you 
      specified using -language)

   2> Edit the file, change the newtext entries as needed

   3> load the patchfile

      QuestionFixMiddle.pl -load patch.txt

   Each newtext that was modified in the file will be modified in 
   the database
===============================================================================

# QuestionFixLast.pl
#
# This utility is for cleaning up question/questiontext text
#
# This utility is the last step in cleaning up the questions when adding a 
#  new foreign language. 
#
# Specifically, this utility:
#  -Looks for and replaces UTF-8 bytecode sequences and replaces them with html
#    entities.
#
#  -Looks for certain html entities (&amp; &lt; &gt;) and replaces them with the
#    character. (This is necessary because the text sometimes contains template code)
#
#  As a secondary feature, this utility can be used to dump the hex codes of
#    the non ascii characters used in the text
#
# See the bottom of this file, or run this script with no options to
#  get usage information.
#
# See the README for more information.
#
# Commandline help:
-------------------------------------------------------------------------------
QuestionFixLast.pl - Utility to convert utf-8 characters to html 
                            entities for questionnaires.questiontext.text data.

USAGE: QuestionFixLast.pl [options]

WHERE: [options] is one or more of:
   -language=spanish .. Pick language to clean (english|spanish|portuguese)
   -test .............. Run, but dont actually update the database
   -doit .............. Run, actually update the database
   -id=questiontextid.. Only process this record
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)
   -debug ............. (with -test) show string changes
   -debug2 ............ (with -test) show utf-8 char bytes

EXAMPLES:
   QuestionFixLast.pl -lang=spanish -test
   QuestionFixLast.pl -lang=spanish -test -debug
   QuestionFixLast.pl -lang=spanish -doit

NOTES:
   The following modification are applied to all active questiontext.text
   fields in the specified language:
   
   - Known UTF-8 char codes are replaced with html entities.
   - Certain html entities (&amp; &lt; &gt;) are replaced with the char

   - this utility can be used to dump the hex codes of the non ascii 
     characters used in the text (using -test and -debug)
===============================================================================

#!perl
#
# QuestionView.pl
#
# This utility is for examining question/questiontext text
#
# This utility is usefull for determining what problems exist, what 
#  foreign fields are missing, what <var> names are present, etc...
#
# This utility can generate html as well as text.  This can be usefull for
#  detecting broken tags, as all following html will likely be screwed up.
#
# See the bottom of this file, or run this script with no options to
#  get usage information.
#
# See the README for more information.
#
# Some examples:
#
#   Generate a html page of all the questions:
#
#     QuestionView.pl -e -html > foo.html
#
#   Generate a html page of all the questions and the protugeuse translations:
#
#     QuestionView.pl -language=portuguese -e -f -html > foo.html
#
#   Display all questions (and associated questiontext) that have both english
#   and spanish text:
#
#     QuestionView.pl -language=spanish -e -f
#
#   Display all questions (and associated questiontext) that have both english
#   and spanish text, and that have the "<" char encoded as an html entity
#   in ther spanish text:
#
#     QuestionView.pl -language=spanish -e -f -ftext="&lt;"
#
#   Create a web page containing all questions (and associated questiontext) that 
#    have <var>'s in the english text, but dont have <var>'s in the spanish text
#
#     QuestionView.pl -language=spanish -e -f -ve -vnf -html > foo.html
#
#   Generate question index files for the web page editor:
#
#     QuestionView.pl -language=spanish -e -f -idsonly > 5912
#     QuestionView.pl -language=portuguese -e -f -idsonly > 5265
#
# Commandline help:
-------------------------------------------------------------------------------
QuestionView.pl - Utility for dumping TriVox question string data

USAGE: tvquestions.pl [options]

WHERE: [options] is one or more of:
    -language=9999 . Specify language in addition to english (spanish)
    -all ........... Show all questions
    -e ............. Exclude all but questions that have english text
    -ne ............ Exclude all but questions that dont have english text
    -f ............. Exclude all but questions that have foreign text
    -nf ............ Exclude all but questions that dont have foreign text
    -v ............. Exclude all but questions that have vars
    -nv ............ Exclude all but questions that dont have vars
    -ve ............ Exclude all but questions that have english text vars
    -vf ............ Exclude all but questions that have foreign text vars
    -vne ........... Exclude all but questions that dont have english text vars
    -vnf ........... Exclude all but questions that dont have foreign text vars
    -vars .......... Include vars and parens
    -etext=str ..... Exclude all but questions that have this english text
    -ftext=str ..... Exclude all but questions that have this foreign text
    -id ............ Exclude all but questions with this question id
    -eid ........... Exclude all but questions with this questiontext id
    -fid ........... Exclude all but questions with this questiontext id
    -host=foo ...... Set the mysqlhost (localhost)
    -username=foo .. Set the mysqlusername (avocate)
    -password=foo .. Set the mysqlpassword (****************)
    -html .......... Generate html (default is text)

EXAMPLES: 
    QuestionView.pl -lang=portuguese -all
    QuestionView.pl -e -f -v -html
    QuestionView.pl -host=trivox-db.cymcwhoejtz8.us-east-1.rds.amazonaws.com -all
    UifieldView.pl -language=spanish -e -f -ftext="&lt;"

NOTES:
    -language can be set to:
       spanish or 5912 for Spanish
       portuguese or 5265 for Portuguese
===============================================================================
