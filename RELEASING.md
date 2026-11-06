# Pubblicare Draxtilities

Il repository sorgente è <https://github.com/draxas/Draxtilities>.
Per i controlli locali serve Python 3.9 o successivo.
Il workflow `.github/workflows/release.yml` controlla il progetto a ogni push su
`main`, nelle pull request e quando viene avviato manualmente da Actions.
La validazione comprende i test Lua 5.1 con API simulate, il manifest e una
prova di packaging senza upload.
Un push di un tag `v*` avvia anche il packaging e la pubblicazione della release.

## Prima pubblicazione

La versione iniziale nel TOC è `0.1.1`. Dalla cartella del repository:

```powershell
python scripts/validate_release.py --tag v0.1.1
git add .
git diff --cached --stat
git commit -m "Add modular item safeguards with EllesmereUI integration"
git push -u origin main
git tag -a v0.1.1 -m "Draxtilities 0.1.1"
git push origin v0.1.1
```

Il push su `main` pubblica il sorgente. Il push del tag pubblica anche la
versione installabile: apri **Actions → Validate and release** per seguirne
l'esito, poi controlla la pagina [Releases](https://github.com/draxas/Draxtilities/releases).

La release deve contenere:

- `Draxtilities-v0.1.1.zip`, con una sola cartella principale `Draxtilities/`.
- `release.json`, generato dal packager con i metadati per i gestori di addon.

GitHub aggiunge anche gli archivi automatici **Source code**: per installare
l'addon usa lo ZIP generato dal workflow.

## Aggiornamenti successivi

1. Modifica il codice e prova le funzionalità interessate nel client WoW.
   Esegui anche i test automatici descritti nel README.
2. Aggiorna `## Version` in `Draxtilities.toc`, per esempio a `0.1.2`.
3. Aggiungi in cima a `CHANGELOG.md` una sezione `## 0.1.2` con le novità.
4. Verifica, committa e pubblica:

```powershell
python scripts/validate_release.py --tag v0.1.2
git add .
git commit
git push origin main
git tag -a v0.1.2 -m "Draxtilities 0.1.2"
git push origin v0.1.2
```

Il tag deve corrispondere esattamente a `v` più la versione nel TOC.
Per il commit scrivi un messaggio in inglese che descriva le modifiche implementate.
Per una beta usa, per esempio, `0.1.2-beta.1` nel TOC e `v0.1.2-beta.1` come tag.
Il packager riconosce `alpha` e `beta` e pubblica queste versioni come prerelease.
Gli utenti del canale stabile ricevono le release stabili.

I normali commit su `main` non distribuiscono aggiornamenti agli utenti.
Per correggere una release già pubblicata usa una nuova versione e un nuovo tag.

## WoWUp: installazione e aggiornamenti

In **Get Addons → Install from URL**, seleziona il client Retail e incolla:

```text
https://github.com/draxas/Draxtilities
```

È necessaria almeno una release pubblicata con lo ZIP installabile allegato.
Gli utenti continuano a usare lo stesso URL per tutte le versioni.
WoWUp controlla le release GitHub e propone quelle compatibili con il client
e il canale selezionati; le installa tramite **Update** o con l'aggiornamento
automatico abilitato. La frequenza dei controlli dipende dalle impostazioni di WoWUp.

Un URL diretto allo ZIP permette un'installazione singola: WoWUp lo contrassegna
come ignorato perché non ha una sorgente da interrogare per gli aggiornamenti.
EllesmereUI 9.7.3 o successiva deve essere installato separatamente.

Durante lo sviluppo tieni il checkout Git separato dalla copia aggiornata con
WoWUp, per evitare che gli aggiornamenti sovrascrivano i file su cui lavori.

## Packaging e permessi GitHub

Usiamo [BigWigs Packager](https://github.com/BigWigsMods/packager) con
`.pkgmeta` per mantenere il nome della cartella `Draxtilities`, includere il
changelog ed escludere gli strumenti di sviluppo dal pacchetto.
Il workflow pubblica soltanto su GitHub; non richiede account CurseForge o Wago.

Per creare release usa il `GITHUB_TOKEN` fornito da GitHub, con
`permissions: contents: write` nel solo job di pubblicazione. Non devi creare
un token personale. Il repository deve consentire l'esecuzione di GitHub Actions.
Se una policy dell'account limita i permessi del token, controlla
**Settings → Actions → General**.

## Licenza

Il codice originale di Draxtilities è distribuito con [licenza MIT](LICENSE).
Il pacchetto non include EllesmereUI o file di World of Warcraft.
La licenza riguarda questo progetto; l'uso e la distribuzione degli addon
restano soggetti alla [policy Blizzard](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642).

## Riferimenti

- [WoWUp: installazione da URL](https://wowup.io/guide/get-addons/overview)
- [BigWigs Packager: workflow GitHub Actions](https://github.com/BigWigsMods/packager/wiki/GitHub-Actions-workflow)
- [BigWigs Packager: configurazione .pkgmeta](https://github.com/BigWigsMods/packager/wiki/Preparing-the-PackageMeta-File)
