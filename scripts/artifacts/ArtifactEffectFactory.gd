class_name ArtifactEffectFactory
extends RefCounted
## Maps an ArtifactDefinition's effect_id string to its concrete effect class.
## Adding a new artifact behaviour means adding one line here and one new
## ArtifactEffectBase subclass - no existing effect code changes.

static func create(effect_id: String) -> ArtifactEffectBase:
	match effect_id:
		"cinder_ring":
			return CinderRingEffect.new()
		"moonstone_charm":
			return MoonstoneCharmEffect.new()
		"thorned_coin":
			return ThornedCoinEffect.new()
		"hunters_eye":
			return HuntersEyeEffect.new()
		"broken_crown":
			return BrokenCrownEffect.new()
		"rat_kings_fang":
			return VenomousFangEffect.new()
		"warlords_renewal":
			return WarlordsRenewalEffect.new()
		"heart_of_the_hollow":
			return HeartOfTheHollowEffect.new()
		"bug_catchers_net":
			return BugCatchersNetEffect.new()
		_:
			push_warning("ArtifactEffectFactory: unknown effect_id '%s'" % effect_id)
			return null
