@echo off
title HAREM ALTIN BOTU - WATCHDOG MODU
color 0A

:baslangic
cls
echo =================================================
echo   BOT BASLATILIYOR... (%date% - %time%)
echo =================================================

:: 1. ADIM: KÖK TEMİZLİK
:: Arkada asılı kalan Chrome ve Chromedriver varsa zorla kapatır.
echo Onceki oturumlar temizleniyor...
taskkill /F /IM chrome.exe /T >nul 2>&1
taskkill /F /IM chromedriver.exe /T >nul 2>&1

:: 2. ADIM: SCRIPTI ÇALIŞTIR
:: Script çalıştığı sürece bu satırda bekler.
:: Script hata verip kapanırsa bir alt satıra geçer.
python kuyumcu.py

:: 3. ADIM: YENİDEN BAŞLATMA DÖNGÜSÜ
echo =================================================
echo   UYARI: Script kapandi veya hata verdi!
echo   Sistem temizlenip 10 saniye icinde yeniden baslatilacak...
echo =================================================

:: 10 saniye geri sayım (İstersen süreyi artırabilirsin)
timeout /t 10

:: Başa dön
goto baslangic