#!/usr/bin/env bash
# Creates a self-signed code-signing identity in the login keychain.
#
# Why this exists: macOS ties the Accessibility grant to an app's code signature, and an ad-hoc
# signature changes on every build — so without this, every rebuild silently drops the grant and
# Paste fails until you re-tick the box in System Settings. Signing with a stable identity pins the
# app's designated requirement to this certificate, and the grant survives rebuilds.
#
# The certificate is never trusted as a root and does not need to be: codesign accepts it by name
# regardless, and TCC matches on the leaf certificate hash rather than on trust. It will not appear
# in `security find-identity -v -p codesigning`, which lists only trusted identities — that absence
# is expected.
#
# Run once per machine, before install.sh. It is idempotent, and asks for your login keychain
# password once (see authorise_codesign below for why).
set -euo pipefail

CERT_CN="Starkit Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
OPENSSL=/usr/bin/openssl
# The p12 is transient and deleted below. It needs a non-empty password because
# `security import` fails MAC verification on password-less bundles.
P12_PASSWORD=starkit-transient

# Lets /usr/bin/codesign use the new private key without a confirmation dialog.
#
# `security import -A` marks the key "allow all applications", which is only half of it: macOS also
# keeps a *partition list* per key, and codesign is not on it after an import. The result is a
# SecurityAgent prompt on the first signing attempt — and if that dialog is not clickable (a
# non-interactive shell, a remote session, a locked screen) codesign blocks forever rather than
# failing, which looks exactly like a hung build.
#
# Setting the partition list needs the login keychain's own password, so this is the one moment the
# setup is interactive.
authorise_codesign() {
	if [ ! -t 0 ]; then
		echo "! Not running in a terminal, so codesign cannot be authorised now."
		echo "  Re-run scripts/setup-signing.sh from a terminal, or the first build will hang"
		echo "  on an invisible keychain prompt."
		return 0
	fi

	printf 'Login keychain password (not echoed, not stored): '
	IFS= read -rs keychain_password
	printf '\n'

	if security set-key-partition-list \
		-S apple-tool:,apple:,codesign: \
		-s -k "$keychain_password" "$KEYCHAIN" >/dev/null 2>&1; then
		echo "✓ codesign is authorised to use the key — no prompt on first build."
	else
		echo "! Could not set the partition list; the password may have been wrong."
		echo "  The first build will show a keychain prompt instead — click Always Allow."
	fi
	unset keychain_password
}

if security find-certificate -c "$CERT_CN" "$KEYCHAIN" >/dev/null 2>&1; then
	echo "✓ Code-signing identity '$CERT_CN' already exists."
	echo "  Re-authorising codesign anyway, in case the partition list was never set."
	authorise_codesign
	exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/openssl.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions    = ext
prompt             = no

[ dn ]
CN = $CERT_CN

[ ext ]
basicConstraints = critical,CA:false
keyUsage         = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

echo "Generating a self-signed code-signing certificate…"
"$OPENSSL" req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
	-config "$tmp/openssl.cnf" \
	-keyout "$tmp/key.pem" -out "$tmp/cert.pem" 2>/dev/null

"$OPENSSL" pkcs12 -export \
	-inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
	-name "$CERT_CN" -out "$tmp/identity.p12" -passout "pass:$P12_PASSWORD"

echo "Importing it into your login keychain…"
security import "$tmp/identity.p12" -k "$KEYCHAIN" -P "$P12_PASSWORD" -T /usr/bin/codesign -A

authorise_codesign

echo "✓ Identity '$CERT_CN' is ready. Run scripts/install.sh next."
