import graphene

# Define a Mutation class that will handle the `test` mutation
class Test(graphene.Mutation):
    class Arguments:
        # If there are any arguments, define them here.
        # Example: `name = graphene.String(required=True)`
        pass
    
    # Mutation resolve function
    def mutate(self, info):
        # This is where the logic for the mutation goes.
        return "test"

# Root Mutation class that includes the `test` mutation field
class Mutation(graphene.ObjectType):
    test = Test.Field()  # This links the Test mutation to the root mutation.
