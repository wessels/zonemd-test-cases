#!/bin/sh

# Copyright 2021 Verisign, Inc.

RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
NC='\033[0m' # No Color

if test $# -eq 0 ; then
	VERIFIERS=$(ls verifiers/*.sh)
else
	VERIFIERS=$*
fi

mkdir -p 'results'
RUNDIR=$(date -u "+results/%Y-%m-%d")
mkdir "$RUNDIR"
TBL="$RUNDIR/tbl"
cp /dev/null "$TBL"

printf "<tr>" >> "$TBL"
for Z in $(cd zones || exit ; ls) ; do
	printf "\t<tr>" >> "$TBL"
done
printf "\n" >> "$TBL"

printf "<td>&nbsp;</td>" >> "$TBL"
for Z in $(cd zones || exit ; ls) ; do
	printf "\t<td class=\"%s\"><a href=\"%s\">%s</a></td>" 'zone' "zone-$Z.txt" "$Z" >> "$TBL"
done
printf "\n" >> "$TBL"

for VSH in $VERIFIERS ; do
	V=$(basename "$VSH" .sh)
	NPASS=0
	NFAIL=0
	#VL="logs/$V.log"
	#cp /dev/null "$VL"
	printf "<th>%s</th>" "$V" >> "$TBL"

	for Z in $(cd zones || exit ; ls) ; do
		origin=''
		zonefile=''
		expected_result=''
		try_canonical=''
		# shellcheck source=zones/01-sha384-simple/config
		. "zones/$Z/config"
		VL=$(printf "%s/log-%s-%s.txt" "$RUNDIR" "$V" "$Z")
		cp /dev/null "$VL"
		cp -p "zones/$Z/$zonefile" "$RUNDIR/zone-$Z.txt"
		printf "%s verifying %s: " "$V" "$Z"
		sh "verifiers/$V.sh" "$origin" "zones/$Z/$zonefile" >> "$VL" 2>&1
		result=$?
		RETRIES=''
		if test '(' $result -eq 1 -a "$expected_result" = "success" ')' -o '(' $result -eq 0 -a "$expected_result" = "failure" ')' ; then
			if test "$try_canonical" = "yes" ; then
				echo "Retry after canonicalizing with named-checkzone" >> "$VL"
				TF=$(mktemp)
				trap 'rm -f $TF' EXIT
				named-checkzone -i none -o "$TF" "$origin" "zones/$Z/$zonefile" >> "$VL" 2>&1
				sh "verifiers/$V.sh" "$origin" "$TF" >> "$VL" 2>&1
				result=$?
				rm -f "$TF"
				RETRIES=" ${YEL}(tried named-checkzone)"
			fi
		fi
		printf "\n%s exited with status %d\n" "$V.sh" "$result" >> "$VL"
		if test $result -eq 0 -a "$expected_result" = "success" ; then
			echo "${GRN}Success as expected${RETRIES}${NC}"
			passfail='pass'
			NPASS=$((NPASS + 1))
		elif test $result -ne 0 -a "$expected_result" = "failure" ; then
			echo "${GRN}Failed as expected${RETRIES}${NC}"
			passfail='pass'
			NPASS=$((NPASS + 1))
		else 
			echo "${RED}Expected $expected_result but return code was $result${RETRIES}${NC}"
			passfail='fail'
			NFAIL=$((NFAIL + 1))
		fi
		printf "\t<td class=\"%s\"><a href=\"%s\">%s</a></td>" "$passfail" $(basename "$VL") "$passfail" >> "$TBL"
	done
	echo "Tests Passed: $NPASS"
	echo "Tests Failed: $NFAIL"
	printf "\n" >> "$TBL"
done

printf "</tr>" >> "$TBL"
for Z in $(cd zones || exit ; ls) ; do
	printf "\t</tr>" >> "$TBL"
done
printf "\n" >> "$TBL"

HTML="$RUNDIR/index.html"
cat >"$HTML" <<EOF
<style type="text/css">
  table, th, td {
    padding: 10px;
    border: 1px solid black;
    border-collapse: collapse;
  }
  td.pass { text-align:center }
  td.pass a { color:green; }
  td.fail { text-align:center }
  td.fail a { color:red; }
  td.zone { text-align:left }
</style>
EOF

printf "<table>\n" >> "$HTML"
rs -c -C -T < "$TBL" >> "$HTML"
printf "</table>\n" >> "$HTML"
rm -f "$TBL"
