# House IV — Operations × Controls

**Cascade:** [I Goals × Functions](./house-1-goals-functions.md) → [II Functions × Components](./house-2-functions-components.md) → [III Components × Operations](./house-3-components-operations.md) → **IV Operations × Controls** · [all four in DESIGN.md](../../DESIGN.md#houses-of-quality)

Process control: the operations against the gates that would catch a regression in one.

[`DESIGN.md` §11](../../DESIGN.md#11-the-deployment-cascade--houses-iii-and-iv) holds the relation
cells this renders. The importance column is [House III](./house-3-components-operations.md)'s
relative weight.

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

% --- House IV: 9 Operations x 10 Controls -----------------------------
\def\qfdNW{9}
\def\qfdNH{10}
\def\qfdWhatW{4.8}
\def\qfdImpW{0.9}
\def\qfdHdrH{3.5}
\def\qfdBasementN{4}
\qfdshowcompetitivefalse
\def\qfdWhatsTitle{Operations, carried down from House III}
\def\qfdImpTitle{Rel.\ \%}
\def\qfdProjectTitle{Starkit --- House IV}
\def\qfdConcept{The nine \textbf{Operations}, each carrying the weight House
  III computed for it, against the ten \textbf{Controls} that would catch a
  regression in one. This is where the cascade stops.}

\begin{document}
\begin{qfdhouse}

  % ---- WHATs: the Operations, in House III's column order ----
  \pgfmathsetmacro{\qfdWhatTextW}{\qfdWhatW - 0.2}
  \foreach \r/\t in {%
    1/{O1 swift build},
    2/{O2 codesign, stable id},
    3/{O3 Starkit registry},
    4/{O4 gleam build},
    5/{O5 register at login},
    6/{O6 swift test},
    7/{O7 run --dry-run},
    8/{O8 create, edit, delete},
    9/{O9 run --bench}}
    \node[anchor=west, font=\scriptsize,
          text width=\qfdWhatTextW cm, align=left]
      at ({\qfdLeftEdge + 0.1}, {-\r + 0.5}) {\t};

  % Importance = House III's relative weight per Operation.
  \foreach \r/\imp in {%
    1/48.4, 2/2.1, 3/2.2, 4/4.8, 5/2.1, 6/15.9, 7/5.9, 8/3.5, 9/14.8}
    \node[font=\scriptsize\bfseries] at ({-\qfdImpW/2}, {-\r + 0.5}) {\imp};

  % ---- HOWs: the Controls, from ci.yml and SPEC.md ----
  \foreach \c/\t in {%
    1/{K1 CI on push and PR},
    2/{K2 codesign --verify},
    3/{K3 gleam format --check},
    4/{K4 gleam test in CI},
    5/{K5 unpinned brew install},
    6/{K6 swift test in CI},
    7/{K7 menu bar goes red},
    8/{K8 the bench protocol},
    9/{K9 stapler, spctl},
    10/{K10 exit non-zero}}
    \node[rotate=90, anchor=west, font=\scriptsize]
      at ({\c - 0.5}, 0.15) {\t};

  % ---- Relations ----
  \foreach \c/\r/\s in {%
    1/1/S, 6/1/M,                       % O1 <- CI assembles it; swift test needs it standing
    2/2/S, 1/2/M, 9/2/M,                % O2 <- verify the bundle; CI; would Gatekeeper open it
    1/3/S, 3/3/S, 4/3/M,                % O3 <- CI generates it; it must stay format-clean; the seed's tests import it
    1/4/S, 4/4/S, 5/4/S,                % O4 <- CI; gleam test; an unpinned Toolchain release breaks here first
    10/5/S, 7/5/M,                      % O5 <- prints what macOS reports and exits non-zero when it differs
    1/6/S, 6/6/S,                       % O6 <- CI runs it
    6/7/M,                              % O7 <- only the Effect decode suite reaches this path
    7/8/S, 3/8/M,                       % O8 <- a template with a hole in it turns the bar red in 200 ms
    8/9/S}                              % O9 <- the protocol is the whole control
    \node[qfdrel/\s] at ({\c - 0.5}, {-\r + 0.5}) {};

  % ---- Roof: Control couplings ----
  \foreach \i/\j/\sym in {%
    1/2/{$+\!+$},       % K1 & K2  : codesign --verify runs inside CI
    1/3/{$+\!+$},       % K1 & K3  : format --check runs inside CI
    1/4/{$+\!+$},       % K1 & K4  : gleam test runs inside CI
    1/5/{$+\!+$},       % K1 & K5  : the unpinned install runs inside CI
    1/6/{$+\!+$},       % K1 & K6  : swift test runs inside CI
    4/5/{$+\!+$},       % K4 & K5  : an unpinned Toolchain is only a signal because tests run after it
    2/9/{$+$},          % K2 & K9  : both guard the signature, one before and one after notarization
    1/7/{$-$},          % K1 & K7  : the menu bar is a runtime control CI cannot be
    1/8/{$-$}}          % K1 & K8  : the bench protocol is deliberately outside CI
    \node[font=\scriptsize] at (C-\i-\j) {\sym};

  % ---- Basement ----
  \node[anchor=east, font=\scriptsize\itshape]
    at (-0.2, {-\qfdNW - 0.5}) {Fires};
  \node[anchor=east, font=\scriptsize\itshape]
    at (-0.2, {-\qfdNW - 1.5}) {Automated (1--5)};
  \node[anchor=east, font=\scriptsize\itshape]
    at (-0.2, {-\qfdNW - 2.5}) {Absolute weight};
  \node[anchor=east, font=\scriptsize\bfseries]
    at (-0.2, {-\qfdNW - 3.5}) {Relative weight \%};

  \foreach \c/\fires/\auto/\abs/\rel in {%
    1/{push, PR}/5/648.0/50.1,
    2/{CI build}/5/18.9/1.5,
    3/{CI build}/5/30.3/2.3,
    4/{CI build}/5/49.8/3.9,
    5/{CI build}/5/43.2/3.3,
    6/{CI build}/5/306.0/23.7,
    7/{$\leq$200 ms}/5/37.8/2.9,
    8/{by hand}/1/133.2/10.3,
    9/{per release}/2/6.3/0.5,
    10/{per call}/4/18.9/1.5} {
    \node[font=\scriptsize] at ({\c - 0.5}, {-\qfdNW - 0.5}) {\fires};
    \node[font=\scriptsize] at ({\c - 0.5}, {-\qfdNW - 1.5}) {\auto};
    \node[font=\scriptsize] at ({\c - 0.5}, {-\qfdNW - 2.5}) {\abs};
    \node[font=\scriptsize\bfseries] at ({\c - 0.5}, {-\qfdNW - 3.5}) {\rel};
  }

\end{qfdhouse}
\end{document}
```

**CI (50.1 %) and `swift test` (23.7 %) carry three-quarters of the control weight in this system**,
and the third-ranked control is the `--bench` protocol at 10.3 % — by hand, on one machine, five
runs of twenty samples, medians quoted. `SPEC.md` argues for that ("latency assertions in CI would
be flaky and would not be trusted") and §8 records the protocol, so the position is held
deliberately. The number is new: a tenth of the control weight is a person running a flag.

**K7, the menu bar going red, is the most automatic control in the system and is not in CI at all**
— it fires within 200 ms of a save, on the machine, forever. K9 ranks last at 0.5 %, which is right:
it guards one operation that runs at most once per release.

**And the cascade stops here.** No control in this house reaches C1 or C6, because
[House III](./house-3-components-operations.md) gave them no operation to be controlled through, and
[House II](./house-2-functions-components.md) ranked them 1st and 2nd of twelve. G → F → C → O → K
terminates at `swift build` for the two heaviest components in the design. That sentence is the
whole reason to draw four houses instead of one.

---

**Carried from [House III](./house-3-components-operations.md). Nothing carries on from here** —
**Controls** are the last phase of the cascade, so this basement feeds no further house. Read the
chain backwards from any weight in it and you reach a **Goal** in
[House I](./house-1-goals-functions.md) with a number beside it.

Recompute in order I → II → III → IV. Each house reads the one before it, so redrawing them out of
order silently mixes generations — the rule is in
[`DESIGN.md`](../../DESIGN.md#how-to-keep-this-honest) under "How to keep this honest".