# As regras do design system. Arquivo da Bella: PROOF.bend precisa prová-las.

import Base
import ./src/TOKENS.bend as T
import ./SPEC.bend as Spec

# LAW: o padding horizontal do botão pertence à escala de espaçamento.
law btn_padding_in_scale:
  {Spec.in_space_scale(T.btn_padding_x()) == True{} : Bool}

# LAW: o padding do painel pertence à escala de espaçamento.
law panel_padding_in_scale:
  {Spec.in_space_scale(T.panel_padding()) == True{} : Bool}

# LAW: a altura do botão é uma altura de controle (24, 30 ou 36).
law btn_height_in_scale:
  {Spec.in_control_scale(T.btn_height()) == True{} : Bool}

# LAW: raio aninhado. Raio externo = raio interno + padding.
law segmented_radius_nested:
  {U32.is_eq(T.segmented_outer_radius(),
     (T.segmented_inner_radius() + T.segmented_padding() : U32)) == True{} : Bool}

# LAW: proximidade. O espaço dentro de um grupo é menor que o espaço entre grupos.
law inside_less_than_between:
  {(T.field_gap() < T.form_gap() : U32) == True{} : Bool}
