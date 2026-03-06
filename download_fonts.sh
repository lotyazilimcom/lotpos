#!/bin/bash
mkdir -p assets/fonts

# Function to download font
download_font() {
    FAMILY=$1
    URL=$2
    FILENAME=$3
    if [ ! -f "assets/fonts/$FILENAME" ]; then
        echo "Downloading $FAMILY..."
        curl -L -o "assets/fonts/$FILENAME" "$URL"
    else
        echo "$FAMILY already exists."
    fi
}

# 1. Roboto
download_font "Roboto Regular" "https://github.com/google/fonts/raw/main/apache/roboto/Roboto-Regular.ttf" "Roboto-Regular.ttf"
download_font "Roboto Bold" "https://github.com/google/fonts/raw/main/apache/roboto/Roboto-Bold.ttf" "Roboto-Bold.ttf"

# 2. Open Sans
download_font "Open Sans Regular" "https://github.com/google/fonts/raw/main/ofl/opensans/OpenSans%5Bwdth%2Cwght%5D.ttf" "OpenSans-Regular.ttf"

# 3. Lato
download_font "Lato Regular" "https://github.com/google/fonts/raw/main/ofl/lato/Lato-Regular.ttf" "Lato-Regular.ttf"
download_font "Lato Bold" "https://github.com/google/fonts/raw/main/ofl/lato/Lato-Bold.ttf" "Lato-Bold.ttf"

# 4. Montserrat
download_font "Montserrat Regular" "https://github.com/google/fonts/raw/main/ofl/montserrat/Montserrat%5Bwght%5D.ttf" "Montserrat-Regular.ttf"

# 5. Oswald
download_font "Oswald Regular" "https://github.com/google/fonts/raw/main/ofl/oswald/Oswald%5Bwght%5D.ttf" "Oswald-Regular.ttf"

# 6. Raleway
download_font "Raleway Regular" "https://github.com/google/fonts/raw/main/ofl/raleway/Raleway%5Bwght%5D.ttf" "Raleway-Regular.ttf"

# 7. Merriweather
download_font "Merriweather Regular" "https://github.com/google/fonts/raw/main/ofl/merriweather/Merriweather-Regular.ttf" "Merriweather-Regular.ttf"
download_font "Merriweather Bold" "https://github.com/google/fonts/raw/main/ofl/merriweather/Merriweather-Bold.ttf" "Merriweather-Bold.ttf"

# 8. Playfair Display
download_font "Playfair Display Regular" "https://github.com/google/fonts/raw/main/ofl/playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf" "PlayfairDisplay-Regular.ttf"

# 9. Nunito
download_font "Nunito Regular" "https://github.com/google/fonts/raw/main/ofl/nunito/Nunito%5Bwght%5D.ttf" "Nunito-Regular.ttf"

# 10. Noto Sans
download_font "Noto Sans Regular" "https://github.com/google/fonts/raw/main/ofl/notosans/NotoSans%5Bwdth%2Cwght%5D.ttf" "NotoSans-Regular.ttf"

# 11. Titillium Web
download_font "Titillium Web Regular" "https://github.com/google/fonts/raw/main/ofl/titilliumweb/TitilliumWeb-Regular.ttf" "TitilliumWeb-Regular.ttf"
download_font "Titillium Web Bold" "https://github.com/google/fonts/raw/main/ofl/titilliumweb/TitilliumWeb-Bold.ttf" "TitilliumWeb-Bold.ttf"

# 12. Ubuntu
download_font "Ubuntu Regular" "https://github.com/google/fonts/raw/main/ufl/ubuntu/Ubuntu-Regular.ttf" "Ubuntu-Regular.ttf"
download_font "Ubuntu Bold" "https://github.com/google/fonts/raw/main/ufl/ubuntu/Ubuntu-Bold.ttf" "Ubuntu-Bold.ttf"

echo "Fonts downloaded successfully to assets/fonts/"
