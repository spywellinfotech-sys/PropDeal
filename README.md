# PropDeal

Property dealers ka app: apni listings, clients aur doosre dealers ka network.

## App me kya hai
- **Login:** mobile number + password
- **Meri Listing:** property add/edit (photo, kimat, area, BHK, location), Sold/Hide, WhatsApp pe share
- **Network:** PropDeal pe doosre dealers ki active listings, unhe Call/WhatsApp
- **Clients:** buyer/seller/tenant, budget, follow-up date, matching property
- **Directory:** Google Maps se 9 cities ke 115 dealers/builders (network banane ke liye)
- Hindi aur Hinglish

## Kahan kya hai
- `lib/` – Flutter app ka code
- `assets/` – logo aur directory ka data (`contacts.json`)
- `android/` – app ka naam, icon, splash, permissions
- `signing/debug.keystore` – APK sign karne ki key (isi se har nayi APK purani ke upar update hoti hai; ise mat badlo)
- `.github/workflows/build-apk.yml` – har push pe APK banti hai aur **Releases** me `PropDeal.apk` aati hai
- `.github/workflows/api-check.yml` – database ki jaanch (haath se chalana)

## Backend
Supabase project **TransWell** (`toouzmbhlltipjjcyqim`) me `pd_` naam wali tables:
`pd_dealers`, `pd_listings`, `pd_clients`, photo bucket `pd-photos`, signup function `pd-signup`.
TransWell ka data alag hai; PropDeal ke accounts `<mobile>@phone.propdeal.app` email se bante hain.
