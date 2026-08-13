# House II — Functions × Components

**Cascade:** [I Goals × Functions](./house-1-goals-functions.md) → **II Functions × Components** → [III Components × Operations](./house-3-components-operations.md) → [IV Operations × Controls](./house-4-operations-controls.md) · [all four in DESIGN.md](../../DESIGN.md#houses-of-quality)

Part deployment: the functions, carrying the weight House I computed, against the components that realise them.

[`DESIGN.md` §7](../../DESIGN.md#7-components--function--component-map) holds the component list and the relation cells this renders. The importance column *is* [House I](./house-1-goals-functions.md)'s relative weight, so component priority is derived here rather than asserted.

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

% --- House II: 18 Functions x 12 Components ---------------------------
\def\qfdNW{18}
\def\qfdNH{12}
\def\qfdWhatW{5.6}
\def\qfdImpW{0.9}
\def\qfdHdrH{3.0}
\def\qfdBasementN{4}
\qfdshowcompetitivefalse
\def\qfdWhatsTitle{Functions, carried down from House I}
\def\qfdImpTitle{Rel.\ \%}
\def\qfdProjectTitle{Starkit --- House II}
\def\qfdConcept{The eighteen \textbf{Functions}, each carrying the weight
  House I computed for it, against the twelve \textbf{Components} that realise
  them. Component priority is derived here, not asserted.}

\begin{document}
\begin{qfdhouse}

  % ---- WHATs: the Functions, in House I's column order ----
  \pgfmathsetmacro{\qfdWhatTextW}{\qfdWhatW - 0.2}
  \foreach \r/\t in {%
    1/{F1 Put the bar on screen},
    2/{F2 Know the catalogue without building},
    3/{F3 Narrow to a Script as you type},
    4/{F18 Reach a Script by a shorthand},
    5/{F13 Drive the bar from the home row},
    6/{F4 Bring the Artefact up to date, or Refuse},
    7/{F5 Execute the Artefact},
    8/{F6 Gather only the declared Context},
    9/{F7 Perform each Effect in order},
    10/{F8 Hold the chord},
    11/{F9 Be ready after login},
    12/{F10 Surface breakage at save time},
    13/{F12 Report a run that failed},
    14/{F14 Bound how long a run holds the bar},
    15/{F15 Follow the Toolchain the shell reports},
    16/{F11 Turn an unmatched Keyword into a Script},
    17/{F16 Take a Script away},
    18/{F17 Open a Script where it is written}}
    \node[anchor=west, font=\scriptsize,
          text width=\qfdWhatTextW cm, align=left]
      at ({\qfdLeftEdge + 0.1}, {-\r + 0.5}) {\t};

  % Importance = House I's relative weight per Function.
  \foreach \r/\imp in {%
    1/5.4, 2/8.3, 3/3.9, 4/3.9, 5/7.6, 6/6.7, 7/7.4, 8/5.7, 9/6.6,
    10/4.4, 11/6.6, 12/8.6, 13/4.4, 14/4.4, 15/5.4, 16/3.9, 17/3.1, 18/3.9}
    \node[font=\scriptsize\bfseries] at ({-\qfdImpW/2}, {-\r + 0.5}) {\imp};

  % ---- HOWs: the twelve Components ----
  \foreach \c/\t in {%
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
    \node[rotate=90, anchor=west, font=\scriptsize]
      at ({\c - 0.5}, 0.15) {\t};

  % ---- Relations, from section 4's per-Function Component lists ----
  \foreach \c/\r/\s in {%
    1/1/S,                          % F1  -> C1
    2/2/S, 6/2/M,                   % F2  -> C2, C6 (which writes the Manifests)
    1/3/S, 2/3/S,                   % F3  -> C1 (redraw), C2 (match)
    2/4/S, 1/4/M,                   % F18 -> C2, C1
    1/5/S,                          % F13 -> C1
    5/6/S, 6/6/M,                   % F4  -> C5, C6
    4/7/S, 12/7/M,                  % F5  -> C4, C12 (nothing to spawn without it)
    8/8/S,                          % F6  -> C8
    7/9/S, 1/9/M,                   % F7  -> C7, C1 (coupled through activation)
    3/10/S, 10/10/M,                % F8  -> C3, C10
    9/11/S, 12/11/S, 10/11/M,       % F9  -> C9, C12, C10
    6/12/S, 10/12/S, 5/12/M,        % F10 -> C6, C10, C5
    4/13/S, 1/13/M, 10/13/M,        % F12 -> C4, C1, C10
    4/14/S, 1/14/M,                 % F14 -> C4, C1
    12/15/S, 10/15/M,               % F15 -> C12, C10
    11/16/S, 6/16/S,                % F11 -> C11, C6 (the only path to visibility)
    11/17/S, 6/17/S,                % F16 -> C11, C6 (the same argument backwards)
    11/18/S}                        % F17 -> C11
    \node[qfdrel/\s] at ({\c - 0.5}, {-\r + 0.5}) {};

  % ---- Roof: Component couplings section 4 and section 9 record. ----
  \foreach \i/\j/\sym in {%
    1/2/{$+\!+$},       % C1  & C2  : C1 filters what C2 read
    1/3/{$+\!+$},       % C1  & C3  : the chord is what shows the panel
    2/6/{$+\!+$},       % C2  & C6  : C6 rewrites the Manifests C2 reads
    4/7/{$+\!+$},       % C4  & C7  : C4 collects Effects, C7 performs them
    4/8/{$+\!+$},       % C4  & C8  : C8 gathers, C4 feeds the run
    4/12/{$+\!+$},      % C4  & C12 : C4 spawns what C12 resolved
    5/6/{$+\!+$},       % C5  & C6  : the watcher invokes the build
    5/12/{$+\!+$},      % C5  & C12 : same, for gleam
    6/10/{$+\!+$},      % C6  & C10 : the watcher sets the menu bar state
    6/11/{$+\!+$},      % C6  & C11 : scaffold lands a file, C6 registers it
    1/4/{$+$},          % C1  & C4  : the bar stays up for the run
    1/11/{$+$},         % C1  & C11 : create, open and delete all start in the bar
    3/10/{$+$},         % C3  & C10 : a registration failure goes red
    4/5/{$+$},          % C4  & C5  : a Stale check gates a spawn
    5/10/{$+$},         % C5  & C10 : a build that fails goes red
    10/12/{$+$},        % C10 & C12 : a missing runtime is red before it is needed
    1/7/{$-$},          % C1  & C7  : one decision in two components; 19.4 ms is the split
    9/12/{$-$}}         % C9  & C12 : a login-launched app gets a minimal PATH
    \node[font=\scriptsize] at (C-\i-\j) {\sym};

  % ---- Basement: ADR / risk / absolute / relative weight ----
  \node[anchor=east, font=\scriptsize\itshape]
    at (-0.2, {-\qfdNW - 0.5}) {Anchoring ADR};
  \node[anchor=east, font=\scriptsize\itshape]
    at (-0.2, {-\qfdNW - 1.5}) {Risk (1--5)};
  \node[anchor=east, font=\scriptsize\itshape]
    at (-0.2, {-\qfdNW - 2.5}) {Absolute weight};
  \node[anchor=east, font=\scriptsize\bfseries]
    at (-0.2, {-\qfdNW - 3.5}) {Relative weight \%};

  \foreach \c/\adr/\risk/\abs/\rel in {%
    1/{---}/3/4320/15.6,
    2/{---}/1/2997/10.8,
    3/{---}/2/810/2.9,
    4/{1, 3}/5/2997/10.8,
    5/{2}/2/1773/6.4,
    6/{2}/4/3816/13.7,
    7/{---}/5/1215/4.4,
    8/{---}/2/1053/3.8,
    9/{---}/3/1215/4.4,
    10/{---}/1/2871/10.3,
    11/{---}/3/2025/7.3,
    12/{3}/3/2673/9.6} {
    \node[font=\scriptsize] at ({\c - 0.5}, {-\qfdNW - 0.5}) {\adr};
    \node[font=\scriptsize] at ({\c - 0.5}, {-\qfdNW - 1.5}) {\risk};
    \node[font=\scriptsize] at ({\c - 0.5}, {-\qfdNW - 2.5}) {\abs};
    \node[font=\scriptsize\bfseries] at ({\c - 0.5}, {-\qfdNW - 3.5}) {\rel};
  }

\end{qfdhouse}
\end{document}
```

The two bottom rows are the point of drawing it. **Risk and weight rank differently**, and §7's prose only ever named the risk one. C7 Effector is the joint-riskiest component in the system and ranks **9th of 12** by weight, at 4.4 %; C1 SummonPanel ranks **1st** at 15.6 % on a risk of 3. Both readings are correct and they answer different questions: risk says where a mistake costs most, weight says where the goals actually land. What no column here shows is whether anything *checks* a component — that is [House III](./house-3-components-operations.md), and C1 and C6 come out of it with an almost empty row.

---

**Carried from [House I](./house-1-goals-functions.md), carries into [House III](./house-3-components-operations.md).** The importance column came from House I's Rel %; this basement's Rel % becomes House III's, where the **Operations** that build each **Component** inherit its weight.

Recompute in order I → II → III → IV. Each house reads the one before it, so redrawing them out of order silently mixes generations — the rule is in [`DESIGN.md`](../../DESIGN.md#how-to-keep-this-honest) under "How to keep this honest".
