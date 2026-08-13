# House III — Components × Operations

**Cascade:** [I Goals × Functions](./house-1-goals-functions.md) → [II Functions × Components](./house-2-functions-components.md) → **III Components × Operations** → [IV Operations × Controls](./house-4-operations-controls.md) · [all four in DESIGN.md](../../DESIGN.md#houses-of-quality)

Process planning: the components against the commands that produce or verify them.

[`DESIGN.md` §11](../../DESIGN.md#11-the-deployment-cascade--houses-iii-and-iv) holds the relation cells this renders. The operations are `SPEC.md`'s commands and `.github/workflows/ci.yml`'s steps, not a list invented for the house. The importance column is [House II](./house-2-functions-components.md)'s relative weight.

<!-- Rendered from the tables named above. A house is a rendering, not a source: change the
     table first, then redraw this. -->

```tikz

% =====================================================================
% QFD "House of Quality" preamble
% =====================================================================
\usetikzlibrary{arrows.meta, positioning, shapes.geometric, shapes.misc, calc, fit, backgrounds}

\newif\ifqfdshowroof          \qfdshowrooftrue
\newif\ifqfdshowbasement      \qfdshowbasementtrue
\newif\ifqfdshowcompetitive   \qfdshowcompetitivetrue
\newif\ifqfdshowlegend        \qfdshowlegendtrue
\newif\ifqfdshowimportance    \qfdshowimportancetrue
\newif\ifqfdshowcorrlegend    \qfdshowcorrlegendtrue
\newif\ifqfdshowevallegend    \qfdshowevallegendtrue
\newif\ifqfdshowtitle         \qfdshowtitletrue

\def\qfdNW{5}
\def\qfdNH{5}
\def\qfdWhatW{4.0}
\def\qfdImpW{0.9}
\def\qfdCmpW{3}
\def\qfdHdrH{2.6}
\def\qfdBasementN{4}

\def\qfdWhatsTitle{Customer needs}
\def\qfdImpTitle{Imp.\ \%}
\def\qfdPerceptionTitle{Comparative evaluation}
\def\qfdPoorLabel{poor}
\def\qfdExcellentLabel{excellent}
\def\qfdAltOneLabel{Our product}
\def\qfdAltTwoLabel{Competitor A}
\def\qfdAltThreeLabel{Competitor B}
\def\qfdRelTitle{Relation}
\def\qfdCorrTitle{Correlation}
\def\qfdEvalTitle{Evaluation}

\def\qfdProjectTitle{}
\def\qfdConcept{}

\tikzset{
  qfdthin/.style ={line width=0.35pt},
  qfdmed/.style  ={line width=0.7pt},
  qfdstrong/.style={circle, draw, fill=black,
                    minimum size=7pt, inner sep=0pt},
  qfdmod/.style  ={circle, draw,
                    minimum size=7pt, inner sep=0pt, line width=0.8pt},
  qfdweak/.style ={regular polygon, regular polygon sides=3, draw,
                    minimum size=8.5pt, inner sep=0pt, line width=0.7pt},
  qfdrel/.is choice,
  qfdrel/S/.style={qfdstrong},
  qfdrel/M/.style={qfdmod},
  qfdrel/W/.style={qfdweak},
  qfdalt1mk/.style={circle, draw, fill=black,
                    minimum size=6pt, inner sep=0pt, line width=1pt},
  qfdalt1ln/.style={line width=1.2pt},
  qfdalt2mk/.style={regular polygon, regular polygon sides=3, draw,
                    fill=black, minimum size=6pt, inner sep=0pt,
                    line width=0.7pt},
  qfdalt2ln/.style={line width=0.7pt, dashed},
  qfdalt3mk/.style={rectangle, draw, fill=black,
                    minimum size=5pt, inner sep=0pt, line width=0.7pt},
  qfdalt3ln/.style={line width=0.7pt, dotted},
}

\newcommand{\qfdDrawGrid}{%
  \foreach \c in {1,...,\qfdNHm} \draw[qfdthin] (\c, 0) -- (\c, -\qfdNW);
  \foreach \r in {1,...,\qfdNWm} \draw[qfdthin] (0, -\r) -- (\qfdNH, -\r);
  \foreach \r in {1,...,\qfdNWm}
    \draw[qfdthin] (\qfdLeftEdge, -\r) -- (0, -\r);
  \ifqfdshowroof
    \foreach \c in {1,...,\qfdNHm}
      \draw[qfdthin] (\c, 0) -- (\c, \qfdHdrH);
  \fi
  \ifqfdshowcompetitive
    \foreach \r in {1,...,\qfdNWm}
      \draw[qfdthin] (\qfdNH, -\r) -- (\qfdNH+\qfdCmpW, -\r);
  \fi
  \ifqfdshowbasement
    \foreach \r in {1,...,\qfdBasementN}
      \draw[qfdthin] (0, -\qfdNW-\r) -- (\qfdNH, -\qfdNW-\r);
    \foreach \c in {1,...,\qfdNHm}
      \draw[qfdthin] (\c, -\qfdNW) -- (\c, -\qfdNW-\qfdBasementN);
  \fi
}

\newcommand{\qfdDrawRoof}{%
  \ifqfdshowroof
    \foreach \k in {1,...,\qfdNHm} {%
      \pgfmathsetmacro{\rx}{(\k+\qfdNH)/2}
      \pgfmathsetmacro{\ry}{\qfdHdrH + (\qfdNH-\k)/2}
      \pgfmathsetmacro{\lx}{\k/2}
      \pgfmathsetmacro{\ly}{\qfdHdrH + \k/2}
      \draw[qfdthin] (\k, \qfdHdrH) -- (\rx, \ry);
      \draw[qfdthin] (\k, \qfdHdrH) -- (\lx, \ly);
    }%
    \draw[qfdmed] (0, \qfdHdrH)
       -- (\qfdNH/2, \qfdApexY) -- (\qfdNH, \qfdHdrH);
    \foreach \i in {1,...,\qfdNH}
      \foreach \k in {1,...,\qfdNH} {%
        \pgfmathtruncatemacro{\jj}{\i+\k}
        \ifnum\jj>\qfdNH\relax\else
          \pgfmathsetmacro{\xx}{\i + \k/2 - 0.5}
          \pgfmathsetmacro{\yy}{\qfdHdrH + \k/2}
          \coordinate (C-\i-\jj) at (\xx, \yy);
        \fi
      }%
  \fi
}

\newcommand{\qfdDrawScale}{%
  \ifqfdshowcompetitive
    \foreach \tk in {0,1,2,3,4,5} {%
      \pgfmathsetmacro{\tx}{\qfdNH + (\tk+0.5)*\qfdCmpW/6}
      \node[anchor=south, font=\scriptsize] at (\tx, 0.02) {\tk};
    }%
    \node[anchor=south, font=\scriptsize\bfseries, align=center]
         at ({\qfdNH + \qfdCmpW/2}, 0.7) {\qfdPerceptionTitle};
    \node[anchor=north, font=\scriptsize\itshape]
         at ({\qfdNH + 0.45}, -\qfdNW) {\qfdPoorLabel};
    \node[anchor=north, font=\scriptsize\itshape]
         at ({\qfdNH + \qfdCmpW - 0.45}, -\qfdNW) {\qfdExcellentLabel};
  \fi
}

\newcommand{\qfdDrawZoneTitles}{%
  \ifqfdshowimportance
    \node[rotate=90, anchor=west, font=\footnotesize\bfseries]
         at ({-\qfdImpW/2}, 0.12) {\qfdImpTitle};
  \fi
  \node[font=\scriptsize\bfseries, align=center, text width=\qfdWhatW cm]
       at ({\qfdLeftEdge + \qfdWhatW/2},
           {\ifqfdshowroof \qfdHdrH/2 \else 0.6 \fi}) {\qfdWhatsTitle};
}

\newcommand{\qfdDrawTitle}{%
  \ifqfdshowtitle
    \ifx\qfdProjectTitle\empty\else
      \pgfmathsetmacro{\qfdTitleX}{\qfdNH/2}
      \pgfmathsetmacro{\qfdTitleY}{\ifqfdshowroof \qfdApexY \else \qfdHdrH \fi + 0.9}
      \pgfmathsetmacro{\qfdSubW}{\qfdNH + 2}
      \node[anchor=south, font=\large\bfseries, align=center]
           at (\qfdTitleX, \qfdTitleY) {\qfdProjectTitle};
      \ifx\qfdConcept\empty\else
        \node[anchor=north, font=\footnotesize\itshape, align=center,
              text width=\qfdSubW cm]
             at (\qfdTitleX, {\qfdTitleY - 0.1}) {\qfdConcept};
      \fi
    \fi
  \fi
}

\newcommand{\qfdDrawFrames}{%
  \begin{scope}[qfdmed]
    \draw (\qfdLeftEdge, 0) rectangle (\qfdNH, -\qfdNW);
    \ifqfdshowimportance \draw (-\qfdImpW, 0) -- (-\qfdImpW, -\qfdNW); \fi
    \draw (0, 0) -- (0, -\qfdNW);
    \ifqfdshowroof
      \draw (0, 0) rectangle (\qfdNH, \qfdHdrH); \fi
    \ifqfdshowbasement
      \draw (0, -\qfdNW) rectangle (\qfdNH, -\qfdNW-\qfdBasementN); \fi
    \ifqfdshowcompetitive
      \draw (\qfdNH, 0) rectangle (\qfdNH+\qfdCmpW, -\qfdNW); \fi
  \end{scope}
}

\newcommand{\qfdDrawLegend}{%
  \ifqfdshowlegend
    \pgfmathsetmacro{\qfdLegX}{%
      \qfdNH + \ifqfdshowcompetitive \qfdCmpW + 0.7 \else 0.7 \fi}
    \pgfmathsetmacro{\qfdLegBottom}{%
      -2.05
      \ifqfdshowroof    \ifqfdshowcorrlegend - 2.55 \fi \fi
      \ifqfdshowcompetitive \ifqfdshowevallegend - 2.20 \fi \fi}
    \pgfmathsetmacro{\qfdLegY}{\qfdHdrH - 0.4}
    \begin{scope}[shift={(\qfdLegX, \qfdLegY)}]
      \draw[qfdmed, rounded corners=2pt]
        (-0.15, 0.4) rectangle (4.5, \qfdLegBottom);
      \node[anchor=west, font=\footnotesize\bfseries] at (0, 0.1)
        {\qfdRelTitle};
      \draw[qfdthin] (0, -0.15) -- (4.35, -0.15);
      \node[qfdstrong] at (0.22, -0.5)  {};
        \node[anchor=west] at (0.5, -0.5)  {Strong (9)};
      \node[qfdmod]    at (0.22, -0.95) {};
        \node[anchor=west] at (0.5, -0.95) {Medium (3)};
      \node[qfdweak]   at (0.22, -1.4)  {};
        \node[anchor=west] at (0.5, -1.4)  {Weak (1)};
      \ifqfdshowroof \ifqfdshowcorrlegend
        \node[anchor=west, font=\footnotesize\bfseries] at (0, -2.10)
          {\qfdCorrTitle};
        \draw[qfdthin] (0, -2.35) -- (4.35, -2.35);
        \node[anchor=west] at (0, -2.70) {{$+\!+$}\quad very positive};
        \node[anchor=west] at (0, -3.05) {{$+$\phantom{$+$}}\quad positive};
        \node[anchor=west] at (0, -3.40) {{$-$\phantom{$-$}}\quad negative};
        \node[anchor=west] at (0, -3.75) {{$-\!-$}\quad very negative};
      \fi \fi
      \ifqfdshowcompetitive \ifqfdshowevallegend
        \pgfmathsetmacro{\qfdEvalTop}{%
          -2.10 \ifqfdshowroof\ifqfdshowcorrlegend - 2.55 \fi\fi}
        \node[anchor=west, font=\footnotesize\bfseries]
          at (0, \qfdEvalTop) {\qfdEvalTitle};
        \pgfmathsetmacro{\qfdEvalSep}{\qfdEvalTop - 0.25}
        \draw[qfdthin] (0, \qfdEvalSep) -- (4.35, \qfdEvalSep);
        \pgfmathsetmacro{\qfdLegA}{\qfdEvalTop - 0.55}
        \draw[qfdalt1ln] (0.05, \qfdLegA) -- (0.45, \qfdLegA);
          \node[qfdalt1mk] at (0.25, \qfdLegA) {};
          \node[anchor=west, font=\bfseries] at (0.55, \qfdLegA)
            {\qfdAltOneLabel};
        \pgfmathsetmacro{\qfdLegB}{\qfdEvalTop - 0.95}
        \draw[qfdalt2ln] (0.05, \qfdLegB) -- (0.45, \qfdLegB);
          \node[qfdalt2mk] at (0.25, \qfdLegB) {};
          \node[anchor=west] at (0.55, \qfdLegB) {\qfdAltTwoLabel};
        \pgfmathsetmacro{\qfdLegC}{\qfdEvalTop - 1.35}
        \draw[qfdalt3ln] (0.05, \qfdLegC) -- (0.45, \qfdLegC);
          \node[qfdalt3mk] at (0.25, \qfdLegC) {};
          \node[anchor=west] at (0.55, \qfdLegC) {\qfdAltThreeLabel};
      \fi \fi
    \end{scope}
  \fi
}

\newenvironment{qfdhouse}{%
  \begin{tikzpicture}[x=1cm, y=1cm, font=\scriptsize,
                      line cap=round, line join=round]
  \ifqfdshowimportance
    \pgfmathsetmacro{\qfdLeftEdge}{-\qfdWhatW-\qfdImpW}
  \else
    \pgfmathsetmacro{\qfdLeftEdge}{-\qfdWhatW}
  \fi
  \pgfmathsetmacro{\qfdApexY}{\qfdHdrH + \qfdNH/2}
  \pgfmathtruncatemacro{\qfdNHm}{\qfdNH - 1}
  \pgfmathtruncatemacro{\qfdNWm}{\qfdNW - 1}
  \qfdDrawGrid
  \qfdDrawRoof
  \qfdDrawScale
  \qfdDrawZoneTitles
  \qfdDrawTitle
}{%
  \qfdDrawFrames
  \qfdDrawLegend
  \end{tikzpicture}%
}

% --- House III: 12 Components x 9 Operations -------------------------
\def\qfdNW{12}
\def\qfdNH{9}
\def\qfdWhatW{4.8}
\def\qfdImpW{0.9}
\def\qfdHdrH{3.5}
\def\qfdBasementN{4}
\qfdshowcompetitivefalse
\def\qfdWhatsTitle{Components, carried down from House II}
\def\qfdImpTitle{Rel.\ \%}
\def\qfdProjectTitle{Starkit --- House III}
\def\qfdConcept{The twelve \textbf{Components}, each carrying the weight
  House II computed for it, against the nine \textbf{Operations} that produce
  or verify them. An empty row is a part nothing checks.}

\begin{document}
\begin{qfdhouse}

  % ---- WHATs: the Components, in section 7's order ----
  \pgfmathsetmacro{\qfdWhatTextW}{\qfdWhatW - 0.2}
  \foreach \r/\t in {%
    1/{C1 SummonPanel},
    2/{C2 Catalogue},
    3/{C3 HotKey},
    4/{C4 Runner},
    5/{C5 Builder},
    6/{C6 Watcher},
    7/{C7 Effector},
    8/{C8 ContextGatherer},
    9/{C9 LoginItem},
    10/{C10 MenuBarStatus},
    11/{C11 Scaffolder},
    12/{C12 Toolchain}}
    \node[anchor=west, font=\scriptsize,
          text width=\qfdWhatTextW cm, align=left]
      at ({\qfdLeftEdge + 0.1}, {-\r + 0.5}) {\t};

  % Importance = House II's relative weight per Component.
  \foreach \r/\imp in {%
    1/15.6, 2/10.8, 3/2.9, 4/10.8, 5/6.4, 6/13.7,
    7/4.4, 8/3.8, 9/4.4, 10/10.3, 11/7.3, 12/9.6}
    \node[font=\scriptsize\bfseries] at ({-\qfdImpW/2}, {-\r + 0.5}) {\imp};

  % ---- HOWs: the Operations, from SPEC.md's Commands and ci.yml ----
  \foreach \c/\t in {%
    1/{O1 swift build},
    2/{O2 codesign, stable id},
    3/{O3 Starkit registry},
    4/{O4 gleam build},
    5/{O5 register at login},
    6/{O6 swift test},
    7/{O7 run --dry-run},
    8/{O8 create, edit, delete},
    9/{O9 run --bench}}
    \node[rotate=90, anchor=west, font=\scriptsize]
      at ({\c - 0.5}, 0.15) {\t};

  % ---- Relations ----
  \foreach \c/\r/\s in {%
    1/1/S,                              % C1  <- swift build, and nothing else
    1/2/S, 6/2/S,                       % C2  <- build; the Manifest suite
    1/3/S,                              % C3  <- swift build, and nothing else
    1/4/S, 4/4/M, 6/4/S, 7/4/S, 9/4/S,  % C4  <- build; an Artefact to spawn; Effect + TerminalColour suites; dry-run; bench
    1/5/S, 4/5/S, 6/5/S, 9/5/S,         % C5  <- build; it invokes gleam build; Staleness suite; F4 is a bench row
    1/6/S, 3/6/M,                       % C6  <- swift build; registry is the verb it runs on save
    1/7/S, 2/7/S, 6/7/M, 7/7/M,         % C7  <- build; a stable signature is what keeps its grant; Effect decode; dry-run
    1/8/S, 9/8/S,                       % C8  <- build; F6 is a bench row
    1/9/S, 5/9/S,                       % C9  <- build; the registration itself
    1/10/S, 6/10/M,                     % C10 <- build; TerminalColour suite
    1/11/S, 8/11/S,                     % C11 <- build; the CLI whose absence shipped a crash
    1/12/S, 9/12/S}                     % C12 <- build; resolve is a bench row
    \node[qfdrel/\s] at ({\c - 0.5}, {-\r + 0.5}) {};

  % ---- Roof: Operation couplings ----
  \foreach \i/\j/\sym in {%
    1/2/{$+\!+$},       % O1 & O2 : codesign signs what the build produced
    1/3/{$+\!+$},       % O1 & O3 : only the built binary can generate the registry
    1/6/{$+\!+$},       % O1 & O6 : swift test needs the build
    3/4/{$+\!+$},       % O3 & O4 : nothing under seed/ typechecks until the registry has run
    1/7/{$+$},          % O1 & O7 : the CLI is the built binary
    1/8/{$+$},          % O1 & O8 : same
    2/5/{$+$},          % O2 & O5 : the registration belongs to the bundle the executable sits in
    2/9/{$+$},          % O2 & O9 : bench must be a release build; debug measured 25.7 against 10.8
    4/9/{$+$}}          % O4 & O9 : bench runs against a built home
    \node[font=\scriptsize] at (C-\i-\j) {\sym};

  % ---- Basement ----
  \node[anchor=east, font=\scriptsize\itshape]
    at (-0.2, {-\qfdNW - 0.5}) {Runs in};
  \node[anchor=east, font=\scriptsize\itshape]
    at (-0.2, {-\qfdNW - 1.5}) {Automated (1--5)};
  \node[anchor=east, font=\scriptsize\itshape]
    at (-0.2, {-\qfdNW - 2.5}) {Absolute weight};
  \node[anchor=east, font=\scriptsize\bfseries]
    at (-0.2, {-\qfdNW - 3.5}) {Relative weight \%};

  \foreach \c/\where/\auto/\abs/\rel in {%
    1/{CI + local}/5/900.0/48.4,
    2/{local}/4/39.6/2.1,
    3/{CI + local}/5/41.1/2.2,
    4/{CI + local}/5/90.0/4.8,
    5/{local}/2/39.6/2.1,
    6/{CI}/5/296.1/15.9,
    7/{local}/1/110.4/5.9,
    8/{local}/1/65.7/3.5,
    9/{local}/1/275.4/14.8} {
    \node[font=\scriptsize] at ({\c - 0.5}, {-\qfdNW - 0.5}) {\where};
    \node[font=\scriptsize] at ({\c - 0.5}, {-\qfdNW - 1.5}) {\auto};
    \node[font=\scriptsize] at ({\c - 0.5}, {-\qfdNW - 2.5}) {\abs};
    \node[font=\scriptsize\bfseries] at ({\c - 0.5}, {-\qfdNW - 3.5}) {\rel};
  }

\end{qfdhouse}
\end{document}
```

**O1 `swift build` at 48.4 % is a degenerate first place** — it produces every component, so it was always going to carry half the house, and it tells you nothing. The informative ranking starts below it: `swift test` (15.9 %) and `run --bench` (14.8 %) are the two verification operations that carry real weight, and between them they reach C2, C4, C5, C7, C8, C10 and C12.

**What they do not reach is C1 and C6** — 29.3 % of the component weight, and rows 1 and 6 of this house hold `swift build` and almost nothing else. `SPEC.md` names both as deliberately untested ("a mock would pass while the app was broken"), so this is an argued position and not an oversight. The house is what puts a number on what the position costs.

The two fail differently, and [`DESIGN.md` §11](../../DESIGN.md#component--operation) works out how: C1 fails loudly, C6 fails *quietly* rather than silently, and repairing a dead watcher takes one command while nothing in the system reports that it stopped. Their weights arrive from [House II](./house-2-functions-components.md); what happens to them next is [House IV](./house-4-operations-controls.md), which is nothing.

---

**Carried from [House II](./house-2-functions-components.md), carries into [House IV](./house-4-operations-controls.md).** This basement's Rel % becomes House IV's importance column, so a **Control** is weighted by the **Operations** it guards and, through them, by the **Goals** at the top of the chain.

Recompute in order I → II → III → IV. Each house reads the one before it, so redrawing them out of order silently mixes generations — the rule is in [`DESIGN.md`](../../DESIGN.md#how-to-keep-this-honest) under "How to keep this honest".
