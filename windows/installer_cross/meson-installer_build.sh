#!/bin/bash

add_common_env() {
  cp $1/bin/libcurl-4.dll $2/ &&
  cp $1/bin/libz.dll.1.2.11 $2/ &&
  cp $1/bin/liblzma-5.dll $2/ &&
  cp $1/bin/libzstd-1.dll $2/ &&
  cp $1/bin/libintl-8.dll $2/ &&
  cp $1/bin/libiconv-2.dll $2/ &&
  cp $1/bin/libsqlite3-0.dll $2/ &&
  cp $1/lib/icuuc64.dll     $2/ &&
  cp $1/lib/icudt64.dll     $2/
}

add_glib_env() {
  cp $1/bin/libglib-2.0-0.dll $2/ &&
  cp $1/bin/libpcre-1.dll $2/
}

add_sdl2_mixer_env() {
  cp $1/bin/SDL2.dll $2/ &&
  cp $1/bin/SDL2_mixer.dll $2/ &&
  cp $1/bin/libvorbis-0.dll $2/ &&
  cp $1/bin/libvorbisfile-3.dll $2/ &&
  cp $1/bin/libogg-0.dll $2/
}

add_gtk_common_env() {
  cp $1/bin/libcairo-2.dll $2/ &&
  cp $1/bin/libcairo-gobject-2.dll $2/ &&
  cp $1/bin/libgdk_pixbuf-2.0-0.dll $2/ &&
  cp $1/bin/libgio-2.0-0.dll $2/ &&
  cp $1/bin/libgobject-2.0-0.dll $2/ &&
  cp $1/bin/libpango-1.0-0.dll $2/ &&
  cp $1/bin/libpangocairo-1.0-0.dll $2/ &&
  cp $1/bin/libpangowin32-1.0-0.dll $2/ &&
  cp $1/bin/libpangoft2-1.0-0.dll $2/ &&
  cp $1/bin/libfontconfig-1.dll $2/ &&
  cp $1/bin/libfreetype-6.dll $2/ &&
  cp $1/bin/libpng16-16.dll $2/ &&
  cp $1/bin/libpixman-1-0.dll $2/ &&
  cp $1/bin/libgmodule-2.0-0.dll $2/ &&
  cp $1/bin/libjpeg-9.dll $2/ &&
  cp $1/bin/libepoxy-0.dll $2/ &&
  cp $1/bin/libfribidi-0.dll $2/ &&
  cp $1/bin/libatk-1.0-0.dll $2/ &&
  cp $1/bin/libffi-8.dll $2/ &&
  cp $1/bin/libharfbuzz-0.dll $2/ &&
  cp $1/bin/libxml2-2.dll $2/ &&
  mkdir -p $2/lib &&
  cp -R $1/lib/gdk-pixbuf-2.0 $2/lib/ &&
  mkdir -p $2/share/icons &&
  cp -R $1/share/locale $2/share/ &&
  cp -R $1/share/icons/Adwaita $2/share/icons/ &&
  mkdir -p $2/bin &&
  cp $1/bin/gdk-pixbuf-query-loaders.exe $2/bin/ &&
  add_glib_env $1 $2
}

add_gtk3_env() {
  add_gtk_common_env $1 $2 &&
  cp $1/bin/libgdk-3-0.dll $2/ &&
  cp $1/bin/libgtk-3-0.dll $2/ &&
  mkdir -p $2/etc &&
  cp -R $1/etc/gtk-3.0 $2/etc/ &&
  cp $1/bin/gtk-update-icon-cache.exe $2/bin/ &&
  cp ./helpers/installer-helper-gtk3.cmd $2/bin/installer-helper.cmd
}

if test "$1" = "" || test "$1" = "-h" || test "$1" = "--help" ||
   test "$2" = "" ; then
  echo "Usage: $0 <crosser dir> <gui>"
  exit 1
fi

DLLSPATH="$1"
GUI="$2"

case $GUI in
  gtk3.22)
    GUINAME="GTK3.22"
    MPGUI="gtk3"
    FCMP="gtk3" ;;
  *)
    echo "Unknown gui type \"$GUI\"" >&2
    exit 1 ;;
esac

if test "$CLIENT" = "" ; then
  CLIENT="$GUI"
fi

if ! test -d "$DLLSPATH" ; then
  echo "Dllstack directory \"$DLLSPATH\" not found!" >&2
  exit 1
fi

if ! ./meson-winbuild.sh "$DLLSPATH" "$GUI" ; then
  exit 1
fi

SETUP=$(grep "CrosserSetup=" $DLLSPATH/crosser.txt | sed -e 's/CrosserSetup="//' -e 's/"//')

VERREV="$(../../fc_version)"

if test "$INST_CROSS_MODE" != "release" ; then
  if test -d ../../.git || test -f ../../.git ; then
    VERREV="$VERREV-$(cd ../.. && git rev-parse --short HEAD)"
    GITREVERT=true
  fi
fi

INSTDIR="meson-install/freeciv-${VERREV}-${SETUP}-${GUI}"

if ! mv $INSTDIR/bin/* $INSTDIR/ ||
   ! mv $INSTDIR/share/freeciv $INSTDIR/data ||
   ! mv $INSTDIR/share/doc $INSTDIR/ ||
   ! mkdir -p $INSTDIR/doc/freeciv/installer ||
   ! cat licenses/header.txt ../../COPYING \
     > $INSTDIR/doc/freeciv/installer/COPYING.installer ||
   ! rm -Rf $INSTDIR/lib ||
   ! cp Freeciv.url $INSTDIR/
then
  echo "Rearranging install directory failed!" >&2
  exit 1
fi

if ! add_common_env "$DLLSPATH" "$INSTDIR" ; then
  echo "Copying common environment failed!" >&2
  exit 1
fi

if test "$GUI" = "ruledit" ; then
  echo "Ruledit installer build not supported yet!" >&2
  exit 1
else
  if ! cp freeciv-server.cmd freeciv-${CLIENT}.cmd freeciv-mp-${FCMP}.cmd $INSTDIR/
  then
    echo "Adding cmd-files failed!" >&2
    exit 1
  fi

  if ! add_sdl2_mixer_env "$DLLSPATH" "$INSTDIR" ; then
    echo "Copying SDL2_mixer environment failed!" >&2
    exit 1
  fi

  case $GUI in
    gtk3.22)
      if ! add_gtk3_env "$DLLSPATH" "$INSTDIR" ; then
        echo "Copying gtk3 environment failed!" >&2
        exit 1
      fi ;;
    sdl2)
      echo "sdl2 installer build not supported yet!" >&2
      exit 1 ;;
    qt5|qt6)
      echo "Qt installer build not supported yet!" >&2
      exit 1 ;;
  esac

  if test "$GUI" = "qt5" || test "$GUI" = "qt6" ; then
    EXE_ID="qt"
  else
    EXE_ID="$GUI"
  fi

  if test "$GUI" = "gtk3.22" || test "$GUI" = "gtk4" ; then
    UNINSTALLER="helpers/uninstaller-helper-gtk3.sh"
  else
    UNINSTALLER=""
  fi

  if ! ./create-freeciv-gtk-qt-nsi.sh "$INSTDIR" "$VERREV" "$GUI" "$GUINAME" \
       "$SETUP" "$MPGUI" "$EXE_ID" "$UNINSTALLER" > meson-freeciv-$SETUP-$VERREV-$GUI.nsi
  then
    exit 1
  fi

  if ! mkdir -p Output ; then
    echo "Creating Output directory failed" >&2
    exit 1
  fi
  if ! makensis meson-freeciv-$SETUP-$VERREV-$GUI.nsi
  then
    echo "Creating installer failed!" >&2
    exit 1
  fi
fi
