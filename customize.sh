#!/system/bin/sh
#
# Universal logger function
# This will print to both the recovery console and the installation log
ui_print() {
  echo "$1"
}

# Set to true to skip extraction of the module zip
SKIPUNZIP=1

# Extract module files
unzip -o "$ZIPFILE" -x 'META-INF/*' -d $MODPATH >&2

# --- Start of Language and String Definitions ---
# Default lang en_US
LANG_VOLUME_KEY_ERROR="- Volume key error! Installation aborted."
LANG_VOLUME_KEY_AGAIN="- Volume key not detected. Please try again."
LANG_SELECT_ATYLE="- Select Style: 5G or 5GE"
LANG_SELECT_ATYLE_5G="- Vol Up = 5G"
LANG_SELECT_ATYLE_5GE="- Vol Down = 5GE"
LANG_SELECTED_5G="- Selected 5G Style"
LANG_SELECTED_5GE="- Selected 5GE Style"
LANG_WARNING="- Your device is not supported! Could not find SystemUI.apk."
# --- End of Language and String Definitions ---

# Load local language if available
locale=$(getprop persist.sys.locale | awk -F "-" '{print $1"_"$NF}')
[ "$locale" = "" ] && locale=$(settings get system system_locales | awk -F "," '{print $1}' | awk -F "-" '{print $1"_"$NF}')
if [ -f "$MODPATH/${locale}.ini" ]; then
  . "$MODPATH/${locale}.ini"
fi

# Set permissions for tools
chmod -R 0755 "$MODPATH/file/tools"
P7Z="$MODPATH/file/tools/7za"

#
# Universal Volume Key Selector for Magisk & KernelSU
# This function replaces the non-portable keycheck binary
#
chooseport() {
  local error=false
  while true; do
    ui_print " "
    ui_print "${LANG_SELECT_ATYLE}"
    ui_print "${LANG_SELECT_ATYLE_5G}"
    ui_print "${LANG_SELECT_ATYLE_5GE}"
    
    # Use Android's built-in getevent tool for compatibility
    # Wait for a key press for 3 seconds
    timeout 3 /system/bin/getevent -lqc 1 2>/dev/null | grep 'KEY_VOLUME' > "$TMPDIR/events"
    
    # Check if the temporary file has any content
    if [ -s "$TMPDIR/events" ]; then
      if grep -q 'KEY_VOLUMEUP' "$TMPDIR/events"; then
        rm -f "$TMPDIR/events"
        return 0 # Return 0 for Volume Up
      elif grep -q 'KEY_VOLUMEDOWN' "$TMPDIR/events"; then
        rm -f "$TMPDIR/events"
        return 1 # Return 1 for Volume Down
      fi
    fi
    
    # If no valid key was detected after the timeout
    $error && abort "${LANG_VOLUME_KEY_ERROR}"
    error=true
    ui_print "${LANG_VOLUME_KEY_AGAIN}"
  done
}

# --- Main Script Logic ---

# Let the user choose the style
if chooseport; then
  ui_print "${LANG_SELECTED_5G}"
  addfile="$MODPATH/file/5G"
else
  ui_print "${LANG_SELECTED_5GE}"
  addfile="$MODPATH/file/5GE"
fi

ui_print " "
ui_print "- Searching for SystemUI.apk..."

# Find the target APK directory
SYSTEMUI_PATH=""
for partition in system vendor product system_ext; do
  # Search for common naming conventions of SystemUI.apk
  for name in "SystemUI.apk" "*SystemUI.apk" "SystemUI*.apk"; do
    # find can return multiple results, we only need the first one
    SYSTEMUI_PATH=$(find "/${partition}" -type f -name "${name}" 2>/dev/null | head -n 1)
    if [ -n "$SYSTEMUI_PATH" ]; then
      break 2 # Break out of both loops
    fi
  done
done

if [ -z "$SYSTEMUI_PATH" ]; then
  abort "${LANG_WARNING}"
fi

ui_print "- Found at: ${SYSTEMUI_PATH}"

# Prepare paths for modification
apkname=$(basename "$SYSTEMUI_PATH")
dir=$(dirname "$SYSTEMUI_PATH")
MOD_DIR_SYSTEMUI="$MODPATH/system$dir"

# Create the necessary directory structure in the module
mkdir -p "$MOD_DIR_SYSTEMUI"

ui_print "- Modifying ${apkname}..."

# Copy the original APK to a temporary location
cp -f "$SYSTEMUI_PATH" "$TMPDIR/SystemUI.zip"

# Use 7zip to add the new resource files into the APK archive
# The 'a' command adds files to an archive.
$P7Z a "$TMPDIR/SystemUI.zip" "$addfile/res" >/dev/null

# Copy the modified APK into your module's directory
cp "$TMPDIR/SystemUI.zip" "$MOD_DIR_SYSTEMUI/$apkname"

ui_print "- Modification complete."
ui_print "- Cleaning up..."

# Delete unnecessary files
rm -rf "$MODPATH/file"
rm -f "$MODPATH"/*.ini
rm -f "$MODPATH"/*.md

# Set permissions for the module files
set_perm_recursive $MODPATH 0 0 0755 0644

ui_print "- Done!"
