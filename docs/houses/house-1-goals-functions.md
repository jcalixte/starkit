# House I — Goals × Functions

**Cascade:** **I Goals × Functions** → [II Functions × Components](./house-2-functions-components.md) → [III Components × Operations](./house-3-components-operations.md) → [IV Operations × Controls](./house-4-operations-controls.md) · [all four in DESIGN.md](../../DESIGN.md#houses-of-quality)

The first house of the QFD cascade: what Starkit is for, against what it must do to deliver that.

`DESIGN.md` §1 holds the **Goals** and their weights, §2 the **Functions** and their targets,
[§5](../../DESIGN.md#5-house-i--goals--functions) the relation cells this renders, and
[§6](../../DESIGN.md#6-roof--function--function) the roof.

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

% --- House I: 7 Goals x 18 Functions -----------------------------------
\def\qfdNW{7}
\def\qfdNH{18}
\def\qfdWhatW{5.2}
\def\qfdImpW{0.9}
\def\qfdHdrH{3.5}
\def\qfdBasementN{4}
\qfdshowcompetitivefalse
\def\qfdWhatsTitle{Goals (the WHATs)}
\def\qfdImpTitle{Weight}
\def\qfdProjectTitle{Starkit --- House I}
\def\qfdConcept{Seven weighted \textbf{Goals} against the eighteen measurable
  \textbf{Functions} that deliver them. The basement computes where the
  engineering weight actually falls.}

\begin{document}
\begin{qfdhouse}

  % ---- WHATs: the seven Goals, in weight order (rows 1..7) ----
  \pgfmathsetmacro{\qfdWhatTextW}{\qfdWhatW - 0.2}
  \foreach \r/\t in {%
    1/{G2 It's there every time I reach for it},
    2/{G1 The automation fires before I notice waiting},
    3/{G4 It costs nothing while I'm not using it},
    4/{G3 A new automation is one file and one minute},
    5/{G7 Upgrading bun or Gleam never breaks it},
    6/{G5 I write Gleam, not glue around Gleam},
    7/{G6 There's almost nothing to remember}}
    \node[anchor=west, font=\scriptsize,
          text width=\qfdWhatTextW cm, align=left]
      at ({\qfdLeftEdge + 0.1}, {-\r + 0.5}) {\t};

  \foreach \r/\imp in {1/10, 2/9, 3/8, 4/7, 5/7, 6/6, 7/6}
    \node[font=\scriptsize\bfseries] at ({-\qfdImpW/2}, {-\r + 0.5}) {\imp};

  % ---- HOWs: the eighteen Functions, grouped as in section 2 ----
  \foreach \c/\t in {%
    1/{F1 bar on screen},
    2/{F2 catalogue, no build},
    3/{F3 narrow as you type},
    4/{F18 shorthand Keyword},
    5/{F13 home row only},
    6/{F4 current, or Refuse},
    7/{F5 execute Artefact},
    8/{F6 gather Context},
    9/{F7 Effects in order},
    10/{F8 hold the chord},
    11/{F9 ready after login},
    12/{F10 breakage at save},
    13/{F12 report a crash},
    14/{F14 bound the run},
    15/{F15 follow Toolchain},
    16/{F11 Keyword to Script},
    17/{F16 take one away},
    18/{F17 open in editor}}
    \node[rotate=90, anchor=west, font=\scriptsize]
      at ({\c - 0.5}, 0.15) {\t};

  % ---- Relations. Every cell is backed by section 4's cascade. ----
  \foreach \c/\r/\s in {%
    % Summon & match
    1/2/S, 1/1/M,                 % F1  -> G1 strong, G2 (first summon = every summon)
    2/2/S, 2/1/S,                 % F2  -> G1, and G2: a cache keeps the bar usable while broken
    3/2/S,                        % F3
    4/2/S,                        % F18
    5/2/S, 5/4/M, 5/7/S,          % F13 -> G1, G3, and G6: inherited bindings, nothing to learn
    % Build & run
    6/1/S, 6/2/M, 6/4/M,          % F4  -> G2 strong, G1, G3
    7/2/S, 7/3/S,                 % F5  -> G1, and G4: no resident process, 0 MB idle
    8/2/S, 8/6/M, 8/7/M,          % F6  -> G1, G5, G6
    % Act
    9/2/S, 9/6/S,                 % F7  -> G1, and G5: Effects are the whole escape-hatch-free surface
    % Survive
    10/1/S,                       % F8
    11/1/S, 11/3/M, 11/5/M,       % F9  -> G2, G4, G7
    12/1/S, 12/4/S, 12/3/M,       % F10 -> G2, G3 (the only path a Script becomes visible), G4
    13/1/S,                       % F12
    14/1/S,                       % F14
    15/5/S, 15/1/M, 15/7/M,       % F15 -> G7, G2, G6
    % Author
    16/4/S, 16/7/M,               % F11
    17/4/S,                       % F16
    18/4/S, 18/6/M}               % F17
    \node[qfdrel/\s] at ({\c - 0.5}, {-\r + 0.5}) {};

  % ---- Roof: only pairs section 4 or section 9 argues for. ----
  \foreach \i/\j/\sym in {%
    2/11/{$+\!+$},      % F2  & F9  : the cached Catalogue is what makes a 3 s boot tolerable
    2/12/{$+\!+$},      % F2  & F10 : the same mechanism seen from two sides
    6/12/{$+\!+$},      % F4  & F10 : the watcher builds on save, so Summon finds it done
    12/16/{$+\!+$},     % F10 & F11 : the watcher is the only path a new Script becomes visible
    12/17/{$+\!+$},     % F10 & F16 : C6 notices the file has gone
    13/14/{$+\!+$},     % F12 & F14 : the deadline's kill is a Refusal that lands in the bar
    1/8/{$+$},          % F1  & F6  : both warm at launch, where nothing is waiting
    6/7/{$+$},          % F4  & F5  : a Stale Artefact Refuses instead of running
    6/15/{$+$},         % F4  & F15 : nothing builds without a resolved gleam
    7/8/{$+$},          % F5  & F6  : the warm read is paid off the run's clock
    7/13/{$+$},         % F5  & F12 : bun's stack trace reaches the Refusal's detail
    7/14/{$+$},         % F5  & F14 : the deadline bounds the run
    7/15/{$+$},         % F5  & F15 : nothing runs without a resolved bun
    5/18/{$+$},         % F13 & F17 : Cmd-O and Alt-Return were free keys in a one-line field
    1/9/{$-$},          % F1  & F7  : the bar must activate, so Paste must hand back (19.4 ms)
    3/4/{$-$},          % F3  & F18 : without bands a shorthand would shadow a Keyword
    5/17/{$-$},         % F13 & F16 : Ctrl-D cost the field its forward-delete
    11/15/{$-$}}        % F9  & F15 : resolving the Toolchain spends 325-510 ms of a 3 s budget
    \node[font=\scriptsize] at (C-\i-\j) {\sym};

  % ---- Basement: target / difficulty / absolute / relative weight ----
  \node[anchor=east, font=\scriptsize\itshape]
    at (-0.2, {-\qfdNW - 0.5}) {Target (now)};
  \node[anchor=east, font=\scriptsize\itshape]
    at (-0.2, {-\qfdNW - 1.5}) {Difficulty (1--5)};
  \node[anchor=east, font=\scriptsize\itshape]
    at (-0.2, {-\qfdNW - 2.5}) {Absolute weight};
  \node[anchor=east, font=\scriptsize\bfseries]
    at (-0.2, {-\qfdNW - 3.5}) {Relative weight \%};

  \foreach \c/\tgt/\diff/\abs/\rel in {%
    1/{$\leq$50 ms}/3/111/5.4,
    2/{$\leq$5 ms}/2/171/8.3,
    3/{$\leq$16 ms}/2/81/3.9,
    4/{4 bands}/2/81/3.9,
    5/{0 mouse}/3/156/7.6,
    6/{$\leq$40 ms}/3/138/6.7,
    7/{$\leq$20 ms}/3/153/7.4,
    8/{$\leq$5 ms}/2/117/5.7,
    9/{$\leq$200 ms}/5/135/6.6,
    10/{100 \%}/2/90/4.4,
    11/{$\leq$3 s}/4/135/6.6,
    12/{$\leq$500 ms}/4/177/8.6,
    13/{survives}/2/90/4.4,
    14/{5 s kill}/2/90/4.4,
    15/{0 config}/3/111/5.4,
    16/{1 file}/3/81/3.9,
    17/{2 keys}/3/63/3.1,
    18/{1 key}/1/81/3.9} {
    \node[font=\scriptsize] at ({\c - 0.5}, {-\qfdNW - 0.5}) {\tgt};
    \node[font=\scriptsize] at ({\c - 0.5}, {-\qfdNW - 1.5}) {\diff};
    \node[font=\scriptsize] at ({\c - 0.5}, {-\qfdNW - 2.5}) {\abs};
    \node[font=\scriptsize\bfseries] at ({\c - 0.5}, {-\qfdNW - 3.5}) {\rel};
  }

\end{qfdhouse}
\end{document}
```

Reading the basement left to right: **F10** (8.6 %) and **F2** (8.3 %) carry the most weight, which
is C6 and C2 — the watcher and the catalogue, and they rank 2nd and joint-3rd once that weight
reaches [House II](./house-2-functions-components.md). `DESIGN.md` §7 already said C6 was "the quiet
load-bearing one" and the arithmetic agrees without having been told to.

Two rows are worth reading against each other. **F17** is the cheapest function in the system
(difficulty 1: one `open`, on a key pair macOS gave away) and still carries 3.9 %. **F7** is the
most expensive (difficulty 5: the only permission-gated operation, the activation hand-back, TCC's
responsible-process rule, two spellings of an application's name) and carries 6.6 %. Its component,
C7, ranks 9th of 12 in [House II](./house-2-functions-components.md) on the same evidence. Effort
and weight are not the same axis, and this is where they diverge hardest.

---

**Carries into [House II](./house-2-functions-components.md).** The Rel % row of this basement *is*
House II's importance column, so the weight a **Function** earns here is what the **Components**
realising it inherit. Nothing downstream is asserted; it is all this row, multiplied.

Recompute in order I → II → III → IV. Each house reads the one before it, so redrawing them out of
order silently mixes generations — the rule is in
[`DESIGN.md`](../../DESIGN.md#how-to-keep-this-honest) under "How to keep this honest".