#[derive(Drop, Serde)]
struct ReputationMetadata {
    name: felt252,  // Name of the reputation token
    description: felt252,  // Description of the skills and achievements
    image: felt252,  // IPFS hash of the image
    skill_category: felt252,  // Main skill category
    rating: u8,  // Current rating (0-100)
    achievements: Array<felt252>,  // List of achievement identifiers
    reputation_score: u256,  // Calculated reputation score
    attributes: Array<MetadataAttribute>  // Additional attributes
}

#[derive(Drop, Serde)]
struct MetadataAttribute {
    trait_type: felt252,
    value: felt252
}

// Helper functions for metadata generation and IPFS integration
trait ReputationMetadataHelpers {
    fn generate_metadata(
        name: felt252,
        description: felt252,
        image: felt252,
        skill_category: felt252,
        rating: u8,
        achievements: Array<felt252>,
        reputation_score: u256,
        attributes: Array<MetadataAttribute>
    ) -> ReputationMetadata;

    fn to_json(self: @ReputationMetadata) -> Array<felt252>;
}

impl ReputationMetadataHelpersImpl of ReputationMetadataHelpers {
    fn generate_metadata(
        name: felt252,
        description: felt252,
        image: felt252,
        skill_category: felt252,
        rating: u8,
        achievements: Array<felt252>,
        reputation_score: u256,
        attributes: Array<MetadataAttribute>
    ) -> ReputationMetadata {
        ReputationMetadata {
            name,
            description,
            image,
            skill_category,
            rating,
            achievements,
            reputation_score,
            attributes
        }
    }

    // Convert metadata to JSON format for IPFS storage
    fn to_json(self: @ReputationMetadata) -> Array<felt252> {
        // This is a simplified implementation - in production you would want to properly
        // escape strings and handle all JSON formatting edge cases
        let mut json = ArrayTrait::new();
        
        // Add basic fields
        json.append('{');
        json.append('"name": "'); json.append(*self.name); json.append('",');
        json.append('"description": "'); json.append(*self.description); json.append('",');
        json.append('"image": "ipfs://'); json.append(*self.image); json.append('",');
        json.append('"skill_category": "'); json.append(*self.skill_category); json.append('",');
        json.append('"rating": '); json.append((*self.rating).into()); json.append(',');
        json.append('"reputation_score": '); json.append((*self.reputation_score).into()); json.append(',');
        
        // Add achievements array
        json.append('"achievements": [');
        let mut i = 0;
        loop {
            if i >= self.achievements.len() {
                break;
            }
            if i > 0 {
                json.append(',');
            }
            json.append('"'); json.append(self.achievements[i]); json.append('"');
            i += 1;
        };
        json.append('],');
        
        // Add attributes array
        json.append('"attributes": [');
        let mut i = 0;
        loop {
            if i >= self.attributes.len() {
                break;
            }
            if i > 0 {
                json.append(',');
            }
            json.append('{');
            json.append('"trait_type": "'); json.append(self.attributes[i].trait_type); json.append('",');
            json.append('"value": "'); json.append(self.attributes[i].value); json.append('"');
            json.append('}');
            i += 1;
        };
        json.append(']');
        
        json.append('}');
        json
    }
} 