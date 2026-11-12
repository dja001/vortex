# Writing preferences

## References and DOIs

- Every reference and DOI you add or modify must be verified: either check it
  online (resolve the DOI at https://doi.org/<doi> or look it up with
  https://api.crossref.org/works/<doi>, and confirm that authors, title, year,
  journal and DOI all match), or have the user confirm it. Never write a
  reference or DOI from memory without verifying it.
- If you cannot verify a reference, leave a visible artefact so it is noticed
  in the PDF: put `\todo{unverified reference: <key>}` (or the document's
  equivalent red-note macro; if it has none,
  `\textcolor{red}{[unverified reference: <key>]}`) right after the
  `\cite{<key>}`, and a `% UNVERIFIED: <reason>` comment above the entry in
  the .bib file. List the unverified references in your final reply.
- When the user confirms a reference, remove both artefacts.
