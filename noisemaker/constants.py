"""Constants used in Noisemaker"""

from __future__ import annotations

import json
import os
from enum import Enum, EnumMeta
from typing import TYPE_CHECKING, Any, Type, TypeVar, cast

# Load constants
_SHARE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "share"))
_CONSTANTS_FILE = os.path.join(_SHARE_DIR, "constants.json")

with open(_CONSTANTS_FILE) as f:
    _CONSTANTS = json.load(f)


def _get_enum_members(name: str) -> dict[str, int]:
    return cast(dict[str, int], _CONSTANTS[name])


if TYPE_CHECKING:
    T = TypeVar("T", bound=Enum)

    class DynamicEnumMeta(EnumMeta):
        def __getattr__(cls, name: str) -> Any:
            raise AttributeError(name)


class DistanceMetricMixin:
    """
    Specify the distance metric used in various operations, such as Voronoi cells, derivatives, and sobel operators.
    """

    @classmethod
    def all(cls) -> list[DistanceMetric]:
        """
        Get all distance metrics except none.

        Returns:
            List of all non-none distance metrics
        """
        return [m for m in cast(Type["DistanceMetric"], cls) if m.name != "none"]

    @classmethod
    def absolute_members(cls) -> list[DistanceMetric]:
        """
        Get all distance metrics that require absolute inputs.

        Returns:
            List of absolute distance metrics (euclidean, manhattan, chebyshev, octagram)
        """
        return [m for m in cast(Type["DistanceMetric"], cls) if cls.is_absolute(m)]

    @classmethod
    def is_absolute(cls, member: DistanceMetric) -> bool:
        """
        Check if a distance metric requires absolute inputs.

        Args:
            member: Distance metric to check

        Returns:
            True if metric requires absolute inputs
        """
        return member.name != "none" and member.value < cast(Type["DistanceMetric"], cls)["triangular"].value

    @classmethod
    def signed_members(cls) -> list[DistanceMetric]:
        """
        Get all distance metrics that require signed inputs.

        Returns:
            List of signed distance metrics (triangular, hexagram, sdf)
        """
        return [m for m in cast(Type["DistanceMetric"], cls) if cls.is_signed(m)]

    @classmethod
    def is_signed(cls, member: DistanceMetric) -> bool:
        """
        Check if a distance metric requires signed inputs.

        Args:
            member: Distance metric to check

        Returns:
            True if metric requires signed inputs
        """
        return member.name != "none" and not cls.is_absolute(member)


if TYPE_CHECKING:

    class DistanceMetric(DistanceMetricMixin, Enum, metaclass=DynamicEnumMeta):
        pass

else:
    DistanceMetric = Enum("DistanceMetric", _get_enum_members("DistanceMetric"), type=DistanceMetricMixin)


class InterpolationTypeMixin:
    """
    Specify the spline point count for interpolation operations.
    """

    pass


if TYPE_CHECKING:

    class InterpolationType(InterpolationTypeMixin, Enum, metaclass=DynamicEnumMeta):
        pass

else:
    InterpolationType = Enum("InterpolationType", _get_enum_members("InterpolationType"), type=InterpolationTypeMixin)


class PointDistributionMixin:
    """
    Point cloud distribution, used by Voronoi and DLA
    """

    @classmethod
    def grid_members(cls) -> list[PointDistribution]:
        """
        Get all grid-based point distributions.

        Returns:
            List of grid-based point distribution types
        """
        return [m for m in cast(Type["PointDistribution"], cls) if cls.is_grid(m)]

    @classmethod
    def circular_members(cls) -> list[PointDistribution]:
        """
        Get all circular point distributions.

        Returns:
            List of circular point distribution types
        """
        return [m for m in cast(Type["PointDistribution"], cls) if cls.is_circular(m)]

    @classmethod
    def is_grid(cls, member: PointDistribution) -> bool:
        """
        Check if a point distribution is grid-based.

        Args:
            member: Point distribution type to check

        Returns:
            True if the distribution is grid-based
        """
        enum_cls = cast(Type["PointDistribution"], cls)
        return bool(member.value >= enum_cls["square"].value and member.value < enum_cls["spiral"].value)

    @classmethod
    def is_circular(cls, member: PointDistribution) -> bool:
        """
        Check if a point distribution is circular.

        Args:
            member: Point distribution type to check

        Returns:
            True if the distribution is circular
        """
        return bool(member.value >= cast(Type["PointDistribution"], cls)["circular"].value)


if TYPE_CHECKING:

    class PointDistribution(PointDistributionMixin, Enum, metaclass=DynamicEnumMeta):
        pass

else:
    PointDistribution = Enum("PointDistribution", _get_enum_members("PointDistribution"), type=PointDistributionMixin)


class ValueDistributionMixin:
    """
    Specify the value distribution function for basic noise.

    .. code-block:: python

       image = basic(freq, [height, width, channels], distrib=ValueDistribution.simplex)
    """

    @classmethod
    def is_noise(cls, member) -> bool:
        """
        Check if a value distribution is noise-based.

        Args:
            member: Value distribution type to check

        Returns:
            True if the distribution is noise-based
        """
        return bool(member and member.value < 5)

    @classmethod
    def is_center_distance(cls, member) -> bool:
        """
        Check if a value distribution is center distance-based.

        Args:
            member: Value distribution type to check

        Returns:
            True if the distribution is center distance-based
        """
        return bool(member and (member.value >= 20) and (member.value < 40))

    @classmethod
    def is_native_size(cls, member) -> bool:
        """The noise type is generated at full-size, rather than upsampled."""
        return cls.is_center_distance(member)


if TYPE_CHECKING:

    class ValueDistribution(ValueDistributionMixin, Enum, metaclass=DynamicEnumMeta):
        pass

else:
    ValueDistribution = Enum("ValueDistribution", _get_enum_members("ValueDistribution"), type=ValueDistributionMixin)


class ValueMaskMixin:
    """ """

    @classmethod
    def conv2d_members(cls) -> list[ValueMask]:
        """
        Get all conv2d-based value masks.

        Returns:
            List of conv2d value mask types
        """
        return [m for m in cast(Type["ValueMask"], cls) if cls.is_conv2d(m)]

    @classmethod
    def is_conv2d(cls, member: ValueMask) -> bool:
        """
        Check if a value mask is conv2d-based.

        Args:
            member: Value mask type to check

        Returns:
            True if the mask is conv2d-based
        """
        return bool(member.name.startswith("conv2d"))

    @classmethod
    def grid_members(cls) -> list[ValueMask]:
        """
        Get all grid-based value masks.

        Returns:
            List of grid-based value mask types
        """
        return [m for m in cast(Type["ValueMask"], cls) if cls.is_grid(m)]

    @classmethod
    def is_grid(cls, member: ValueMask) -> bool:
        """
        Check if a value mask is grid-based.

        Args:
            member: Value mask type to check

        Returns:
            True if the mask is grid-based
        """
        return bool(member.value < cast(Type["ValueMask"], cls)["alphanum_0"].value)

    @classmethod
    def rgb_members(cls) -> list[ValueMask]:
        """
        Get all RGB value masks.

        Returns:
            List of RGB value mask types
        """
        return [m for m in cast(Type["ValueMask"], cls) if cls.is_rgb(m)]

    @classmethod
    def is_rgb(cls, member: ValueMask) -> bool:
        """
        Check if a value mask is RGB-based.

        Args:
            member: Value mask type to check

        Returns:
            True if the mask is RGB-based
        """
        enum_cls = cast(Type["ValueMask"], cls)
        return bool(member.value >= enum_cls["rgb"].value and member.value < enum_cls["sparse"].value)

    @classmethod
    def nonprocedural_members(cls) -> list[ValueMask]:
        """
        Get all non-procedural value masks.

        Returns:
            List of non-procedural value mask types
        """
        return [m for m in cast(Type["ValueMask"], cls) if not cls.is_procedural(m)]

    @classmethod
    def procedural_members(cls) -> list[ValueMask]:
        """
        Get all procedural value masks.

        Returns:
            List of procedural value mask types
        """
        return [m for m in cast(Type["ValueMask"], cls) if cls.is_procedural(m)]

    @classmethod
    def is_procedural(cls, member: ValueMask) -> bool:
        """
        Check if a value mask is procedural.

        Args:
            member: Value mask type to check

        Returns:
            True if the mask is procedural
        """
        return bool(member.value >= cast(Type["ValueMask"], cls)["sparse"].value)

    @classmethod
    def glyph_members(cls) -> list[ValueMask]:
        """
        Get all glyph-based value masks.

        Returns:
            List of glyph-based value mask types
        """
        enum_cls = cast(Type["ValueMask"], cls)
        return [
            m
            for m in enum_cls
            if (m.value >= enum_cls["invaders"].value and m.value <= enum_cls["tromino"].value)
            or (m.value >= enum_cls["lcd"].value and m.value <= enum_cls["arecibo_dna"].value)
            or m.value == enum_cls["emoji"].value
            or m.value == enum_cls["bank_ocr"].value
        ]

    @classmethod
    def is_glyph(cls, member: ValueMask) -> bool:
        """
        Check if a value mask is glyph-based.

        Args:
            member: Value mask type to check

        Returns:
            True if the mask is glyph-based
        """
        return member in cls.glyph_members()


if TYPE_CHECKING:

    class ValueMask(ValueMaskMixin, Enum, metaclass=DynamicEnumMeta):
        pass

else:
    ValueMask = Enum("ValueMask", _get_enum_members("ValueMask"), type=ValueMaskMixin)


class VoronoiDiagramTypeMixin:
    """
    Specify the artistic rendering function used for Voronoi diagrams.
    """

    @classmethod
    def flow_members(cls) -> list[VoronoiDiagramType]:
        """
        Get all flow-based Voronoi diagram types.

        Returns:
            List of flow Voronoi diagram types
        """
        enum_cls = cast(Type["VoronoiDiagramType"], cls)
        return [enum_cls["flow"], enum_cls["color_flow"]]

    @classmethod
    def is_flow_member(cls, member: VoronoiDiagramType) -> bool:
        """
        Check if a Voronoi diagram type is flow-based.

        Args:
            member: Voronoi diagram type to check

        Returns:
            True if the diagram type is flow-based
        """
        return member in cls.flow_members()


if TYPE_CHECKING:

    class VoronoiDiagramType(VoronoiDiagramTypeMixin, Enum, metaclass=DynamicEnumMeta):
        pass

else:
    VoronoiDiagramType = Enum("VoronoiDiagramType", _get_enum_members("VoronoiDiagramType"), type=VoronoiDiagramTypeMixin)


class WormBehaviorMixin:
    """
    Specify the type of heading bias for worms to follow.

    .. code-block:: python

       image = worms(image, behavior=WormBehavior.unruly)
    """

    @classmethod
    def all(cls) -> list[WormBehavior]:
        """
        Get all worm behaviors except none.

        Returns:
            List of all non-none worm behaviors
        """
        return [m for m in cast(Type["WormBehavior"], cls) if m.name != "none"]


if TYPE_CHECKING:

    class WormBehavior(WormBehaviorMixin, Enum, metaclass=DynamicEnumMeta):
        pass

else:
    WormBehavior = Enum("WormBehavior", _get_enum_members("WormBehavior"), type=WormBehaviorMixin)


class OctaveBlendingMixin:
    """Specify the mode for flattening octaves."""

    pass


if TYPE_CHECKING:

    class OctaveBlending(OctaveBlendingMixin, Enum, metaclass=DynamicEnumMeta):
        pass

else:
    OctaveBlending = Enum("OctaveBlending", _get_enum_members("OctaveBlending"), type=OctaveBlendingMixin)


class ColorSpaceMixin:
    """ """

    @classmethod
    def is_color(cls, m: ColorSpace) -> bool:
        """
        Check if a color space has color channels.

        Args:
            m: Color space to check

        Returns:
            True if the color space has color channels (not grayscale)
        """
        return bool(m and m.value > 1)

    @classmethod
    def color_members(cls) -> list[ColorSpace]:
        """
        Get all color spaces with color channels.

        Returns:
            List of color space types with color channels
        """
        return [m for m in cast(Type["ColorSpace"], cls) if cls.is_color(m)]


if TYPE_CHECKING:

    class ColorSpace(ColorSpaceMixin, Enum, metaclass=DynamicEnumMeta):
        pass

else:
    ColorSpace = Enum("ColorSpace", _get_enum_members("ColorSpace"), type=ColorSpaceMixin)
